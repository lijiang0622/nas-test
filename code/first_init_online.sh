#!/bin/bash
set +x
set -e
ping -c 1 124.193.118.114 &>/dev/null
if [ $? -ne 0 ];then
	echo "Can not access 124.193.118.114" > /root/ip.txt
        exit
fi
if [ -f /root/init.txt ];then
	if [ ! -f /etc/docker/daemon.json ];then
        	echo '{"insecure-registries": ["124.193.118.114:9999"]}' > /etc/docker/daemon.json
        	systemctl restart docker
	fi
	sudo mkdir -p /srv/logs/redis
	sudo chmod 777 /srv/logs/redis
        sudo mkdir -p /srv/etc/config/
        sudo cp -rf  /usr/local/src/Casic-Client-DockerDeploy/configs /srv/
	cd /usr/local/src/Casic-Client-DockerDeploy
	sudo docker login -u admin -p tape2019 124.193.118.114:9999
	sudo docker-compose -f docker-compose.yaml  up -d
        rm -rf /root/init.txt
	sed -ri "/first_init\.sh/d" /etc/crontab
        /usr/local/src/Casic-Client-DockerDeploy/data/run.sh -dc
        /usr/local/src/Casic-Client-DockerDeploy/data/run.sh -du

        touch /root/success.txt

fi

