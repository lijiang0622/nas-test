#!/bin/bash
Red='\033[31m'
Zero='\033[0m'
Green='\033[32m'
BaseDir=`dirname $0`
log=/home/yrd/docker_image.log
composehome=packages/Casic-Client-DockerDeploy
composefile=docker-compose.yaml
register=registry.xgdevice.com:9999
user=admin
password=tape2019
baseimg=base-image.tar.gz
nasimg=nas-base-image.tar.gz
[ $(id -u) != "0" ] && { echo -e "${Red}error:You must run as root ${Zero}"; exit 1; }
if [ $BaseDir = "." ];then
	BaseDir=`pwd`
fi
function successLog(){
        if [ $# -lt 1 ];then
                echo "Missing location parameter [message]" |tee -a $log
        fi
	echo -e $Green[`date +%F/%H:%M:%S`] [INFO] $1 $Zero |tee -a $log
	
}
function errorLog(){
	if [ $# -lt 1 ];then
                echo "Missing location parameter [message]" |tee -a $log
        fi

	echo -e  $Red[`date +%F/%H:%M:%S`] [ERROR] $1 $Zero |tee -a $log
}
function del_allimage(){
	for i in `sudo docker image ls |grep -v REPOSITORY |awk -F " " '{print $3}'`
	do 
		sudo docker rmi -f $i
	done
}
function check_login(){
	local login_status=0
	if [ ! -f /root/.docker/config.json ];then
		local login_status=1
	else
		grep $register /root/.docker/config.json >/dev/null
		if [ $? -ne 0 ];then
			local login_status=1
		fi
	fi
        if [ $login_status -ne 0 ];then
                successLog "login $register"
                sudo docker login $register -u $user -p $password
		if [ $? -eq 0 ];then
			successLog "login $register sucessful"
		else
			errorLog "login $register faild"
		fi
        fi
	
	
}
function update_image(){
	successLog "$1"
	if [ $# -lt 1 ];then
		errorLog "Missing location parameter [docker image name]"
		exit
	fi
	sudo docker image ls |grep ${1##*:}|grep ${1%*:} >/dev/null
	if [ $? -eq 0 ];then
		successLog "$1 is exists,start remove it"
		sudo docker rmi $1
		if [ $? -eq 0 ];then
			successLog "remove $1 successful"
		else
			errorLog "remove $1 faild"
		fi
	fi
	sudo docker pull $1
	if [ $? -eq 0 ];then
		successLog "download $1 successful"
	else
		errorLog "download $1 faild"
	fi
}
function image_tar(){
	if [ $# -lt 1 ];then
                errorLog "Missing location parameter [docker image name]"
        fi
	if [[ $1 =~ .*casic.* ]];then
		nas_list=$nas_list$1,	
	else
		base_list=$base_list$1,
	fi

}
function main(){
	if [ ! -f $BaseDir/../$composehome/$composefile ];then
		echo "have no composefile"
		exit 0
	fi
	del_allimage
	for j in `grep image: $BaseDir/../$composehome/$composefile|awk -F " " '{print $2}'`
	do
		check_login
		update_image $j
		image_tar $j
	done
	for k in `cat base.txt`
	do
		update_image $k
		image_tar $k
	done
	sudo rm -rf $baseDir/../packages/docker_image/*
	sudo docker save -o $BaseDir/../packages/docker_image/$baseimg `echo ${base_list} | tr "," " "`
        sudo docker save -o $BaseDir/../packages/docker_image/$nasimg `echo ${nas_list} | tr "," " "`

}

main
#del_allimage
