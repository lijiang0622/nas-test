#!/bin/bash
set +x
set +e
status=`ps -ef |grep /usr/first_init_offline.sh|grep -v grep|wc -l`
home=/usr/local/src/init-status
device=nas
DN=`splfw get DN`
frp_server=frp.xgcinema.com
rtty_server=rtty.xgcinema.com
zabbix_server=zabbix.tapecab.com

if [ ! -d $home ];then
	mkdir $home
fi

if [ $status -gt 3 ];then
	exit 
fi
nasImagePackage=nas-base-image.tar.gz
mac=`ifconfig enp3s0 |grep ether |awk -F " " '{print $2}' | sed "s/://g"`
if [ "$DN" == "" ];then
	DN=$mac
fi
zabbixName="zabbix_${device}_$DN"
net_enp4s0=`ip a |grep -ci "enp4s0"`
Red='\033[31m'
Zero='\033[0m'
Green='\033[32m'

function salt_minion_install(){
	dpkg -l |grep salt-minion > /dev/null
	if [ $? -ne 0 ];then
		echo -e "$Green [INFO]: start install salt-minion $Zero" >> $home/first_init.log
		sudo apt update
		sudo apt install salt-minion -y
		if [ $? -eq 0 ];then
			echo -e "$Green [INFO]: install salt-minion successful $Zero"  >> $home/first_init.log
			sudo systemctl enable salt-minion.service
		else
			echo -e "$Red [ERROR]: install salt-minion filed $Zero"  >> $home/first_init.log
		fi
	fi
	if [ ! -f /etc/salt/minion ];then
		echo -e "$Red [ERROR]: minion config file have no $Zero"  >> $home/first_init.log
		exit
	fi
	sed -ri '/#master:/c\master: salt.tapecab.com' /etc/salt/minion
	sed -ri "/#id:/cid: ht_nas_$mac" /etc/salt/minion
	if [ -f /etc/salt/minion_id ];then
		echo "ht_nas_$mac" > /etc/salt/minion_id
	fi
	if [ ! -f /etc/salt/grains ];then
		touch /etc/salt/grains
	fi
	grep "env: prod" /etc/salt/grains >/dev/null
	if [ $? -ne 0 ];then
		echo -e "$Green [INFO]: init grains parameter env $Zero"  >> $home/first_init.log
		echo "env: prod" >> /etc/salt/grains
	fi
	echo -e "$Green [INFO]: start restart salt-minion $Zero"  >> $home/first_init.log
	sudo systemctl restart salt-minion.service
	if [ $? -eq 0 ];then
		echo -e "$Green [INFO]: restart salt-minion successful $Zero"  >> $home/first_init.log
	else
		echo -e "$Red [ERROR]: restart salt-minion filad $Zero"  >> $home/first_init.log
	fi
}
function install_docker_portainer()
{
  while true; 
  do 
    [ "$(ps aux | grep portainer | grep -v grep)" ] || { 
      docker run -d -it --name portainer --restart=always -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer --admin-password '$2y$05$AH3mQVmkrM9YDH76eBMeVuBjANfnhoK3VDANs21B5U9NBvucKsJlW'; 
      sleep 1;
    };
    [ "$(ps aux | grep portainer | grep -v grep)" ] && break;
    sleep 1; 
  done
}

function install_docker_frpc()
{
  while true; 
  do 
    [ "$(ps aux | grep frpc | grep -v grep)" ] || { 
      docker run -d -it --name nas-frpc --restart=always -e FRPS_IP=$frp_server -e FRPS_PORT=7000 -e HOST_SSH_ID=frp_${device}_$DN -e GEN_CONFIG=1 darcyg/frpc:v0.22.0 ; 
      sleep 1;
    };
    [ "$(ps aux | grep frpc | grep -v grep)" ] && break;
    sleep 1; 
  done
}

function install_docker_rtty()
{
  while true; 
  do 
    [ "$(ps aux | grep rtty | grep -v grep)" ] || { 
      docker run -d -it --name nas-rtty --restart=always -e RTTY_ID=rtty-${device}_$ND -e RTTYS_HOST=$rtty_server -e RTTYS_PORT=5912 darcyg/rtty:v6.4.1 ; 
      sleep 1;
    };
    [ "$(ps aux | grep rtty | grep -v grep)" ] && break;
    sleep 1; 
  done
}


if [ ! -f /usr/local/src/nas-base-image.tar.gz ];then
	echo "/usr/local/src/nas-base-image.tar.gz file does not exist"  >> $home/first_init.log
        exit
fi

if [ ! -f /usr/local/src/base-image.tar.gz ];then
	echo "/usr/local/src/base-image.tar.gz file does not exist"  >> $home/first_init.log
        exit
fi

if [ $net_enp4s0 -ne 0 ];then
	sed -i '/allow-hotplug enp3s0/a\auto enp3s0' /etc/network/interfaces
	sed -i 's/iface enp3s0 inet dhcp/iface enp3s0 inet static/' /etc/network/interfaces
	echo '	address 192.168.77.230/24' >> /etc/network/interfaces
	echo '	gateway 192.168.77.1' >> /etc/network/interfaces
	echo '	dns-nameservers 114.114.115.115 192.168.77.1' >> /etc/network/interfaces
	echo '	dns-search htnas' >> /etc/network/interfaces
fi

if [ -f /root/init.txt ];then
	salt_minion_install
	if [ ! -f /etc/docker/daemon.json ];then
        	echo '{"insecure-registries": ["124.193.118.114:9999"]}' > /etc/docker/daemon.json
        	systemctl restart docker
	fi
	sudo mkdir -p /srv/logs/redis
	sudo chmod 777 /srv/logs/redis
        sudo mkdir -p /srv/etc/config/
        sudo cp -rf /usr/local/src/Casic-Client-DockerDeploy/configs /srv/configs
        sudo cp -rf /usr/local/src/Casic-Client-DockerDeploy/docker-compose.yaml /srv/configs
	cd /srv/configs
	#cd /usr/local/src/Casic-Client-DockerDeploy
	if [ ! -f $home/nas_success.txt ];then
		sudo docker load -i /usr/local/src/$nasImagePackage
		if [ $? -eq 0 ];then
			touch $home/nas_success.txt
		fi
	fi
	if [ ! -f $home/base_success.txt ];then
		sudo docker load -i /usr/local/src/base-image.tar.gz
		if [ $? -eq 0 ];then
			touch $home/base_success.txt
		fi
	fi
	install_docker_portainer
#	install_docker_frpc
#	install_docker_rtty
	
	sudo docker login -u admin -p tape2019 124.193.118.114:9999
	sudo docker-compose -f docker-compose.yaml  up -d
	/usr/local/src/Casic-Client-DockerDeploy/data/run.sh -dc
	check_status=`echo $?`
	echo "mysql-status is $check_status"
        sudo sed -ri 's/^Server=(.*)/Server=zabbix.tapecab.com/' /etc/zabbix/zabbix_agentd.conf
        sudo sed -ri "s/^ServerActive=(.*)/ServerActive=$zabbix_server/" /etc/zabbix/zabbix_agentd.conf
        sudo sed -ri '/# StartAgents=(.*)/a\StartAgents=0' /etc/zabbix/zabbix_agentd.conf
        sudo sed -ri "s/^Hostname=(.*)/Hostname=$zabbixName/" /etc/zabbix/zabbix_agentd.conf
        sudo /etc/init.d/zabbix-agent restart
        sudo zabbix create-host -n $DN
	ping -c 1 192.168.77.230
	if [ $? -eq 0 ];then
		sudo zabbix add-macros -host $zabbixName
	fi
	echo "*/10 * * * * root zabbix add-macros -host $zabbixName" >> /etc/crontab

	if [ $check_status -eq 0 ];then
		# /usr/local/src/Casic-Client-DockerDeploy/data/run.sh -du
		rm -rf /root/init.txt
		sed -ri "/first_init_offline\.sh/d" /etc/crontab
		touch /root/success.txt
		poweroff
		exit
	fi
	reboot

fi

