#!/usr/bin/env bash
#project build nas iso
#auth:both 
Red="\033[31m"
Zero="\033[0m"
Green="\033[32m"
export BaseDir=`dirname $0`
[ $(id -u) != "0" ] && { echo -e "${Red}error:You must run as root ${Zero}"; exit 1; }

if [ $BaseDir == "." ];then
	export BaseDir=`pwd`
fi
export PROJ_SHA=$PROJ_COMMIT_SHA
export PROJ_SHORT=$PROJ_COMMIT_SHORT
export PROJ_TIME=$PROJ_COMMIT_TIME
lcd_config_home=$BaseDir/packages/lcd_script/conf.d/config.conf
if [ -z $CI_COMMIT_TAG ];then
	export ENVIRONMENT=dev
	export ISO_FILENAME=splnas-installation-offline.${CI_PIPELINE_ID}.$PROJ_TIME.$PROJ_SHORT.$ENVIRONMENT.iso
	sed -i "s/device.xgcinema.com/device.xgdevice.com/g" $lcd_config_home
else
	export ENVIRONMENT=release
	export VERSION=$CI_COMMIT_TAG
	export ISO_FILENAME=splnas-installation-offline.$VERSION.${CI_PIPELINE_ID}.$PROJ_TIME.$PROJ_SHORT.$ENVIRONMENT.iso


fi

case $1 in
	online|offline)
		echo -e "${Green}build nas iso for $1${Zero}" ;;
	*)
		echo -e "${Red}Parameter error ./build.sh [online|offline]${Zero}" 
		exit ;;
esac
if [ -d $BaseDir/source/splnas-buildiso ];then
	echo "$BaseDir/source/splnas-buildiso exist!"
	rm -rf $BaseDir/source/splnas-buildiso
	cp -rf $BaseDir/source/splnas-buildiso.bak  $BaseDir/source/splnas-buildiso
else 
	cp -rf $BaseDir/source/splnas-buildiso.bak  $BaseDir/source/splnas-buildiso
fi

if [[ $1 == "online" ]];then
	cp -rf $BaseDir/code/build_online.sh $BaseDir/source/splnas-buildiso/build.sh
else
	cp -rf $BaseDir/code/build_offline.sh $BaseDir/source/splnas-buildiso/build.sh
fi
cd $BaseDir/source/splnas-buildiso
pwd
./build.sh all
