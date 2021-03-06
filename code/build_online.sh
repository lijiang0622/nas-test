#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

ISO_VOL=SPLNAS
ISO_FILE=splnas-installation.iso
NAS_VERSION="version=v0.0.0.1-stable\ndate=`date +%F`"
function buildiso_install_utils()
{
  echo "Install buildiso env and tools ..."
  if [ "$(cat /etc/apt/sources.list | grep ubuntu.com)" ]; then
    sudo sed 's/[a-z0-9\.]*ubuntu.com/mirrors.cn99.com/g' /etc/apt/sources.list -i
    sudo apt-get update
  fi
  if ! which git > /dev/null; then
    echo '  git install start'
    sudo apt-get install git -y
  fi
  if ! which genisoimage > /dev/null; then
    echo '  genisoimage install start'
    sudo apt-get install genisoimage -y
  fi
  if ! ( dpkg -l | cut -d " " -f 3 | grep "^squashfs-tools" > /dev/null ); then
    echo '  squashfs-tools install start'
    sudo apt-get install squashfs-tools -y
  fi
}

function buildiso_first_rootfs()
{
  if [ ! -d "squashfs-root" ]; then
    echo '第一次使用，初始化root'
    #mv ISOFilesystem/live/filesystem.squashfs .
    unsquashfs filesystem.squashfs
  fi
}

function buildiso_del_rootfs_iso()
{
  if [ -f 'ISOFilesystem/live/filesystem.squashfs' ]; then
    echo 'rm ISOFilesystem/live/filesystem.squashfs'
    sudo rm ISOFilesystem/live/filesystem.squashfs
  fi
  if [ -f "$ISO_FILE" ]; then
    echo "rm $ISO_FILE"
    sudo rm $ISO_FILE
  fi
}

function buildiso_clean_rootfs()
{
  if [ -f 'ISOFilesystem/live/filesystem.squashfs' ]; then
    echo 'rm ISOFilesystem/live/filesystem.squashfs'
    sudo rm ISOFilesystem/live/filesystem.squashfs
  fi
  if [ -f "$ISO_FILE" ]; then
    echo "rm $ISO_FILE"
    sudo rm $ISO_FILE
  fi
  if [ -d 'squashfs-root' ]; then
    echo "rm squashfs-root/"
    sudo rm -rf squashfs-root
  fi
}

function buildiso_overlay_rootfs()
{
  echo "copy overlay/ to squashfs-root/ ..."
  cp -R -f overlay/. squashfs-root/ 
}

function buildiso_build_rootfs()
{
  echo "build rootfs ..."
  sudo mksquashfs squashfs-root/ ISOFilesystem/live/filesystem.squashfs -noappend -always-use-fragments
}

function buildiso_build_iso()
{
  echo "build iso ..."
  sudo genisoimage -r -V "$ISO_VOL" -cache-inodes -J -l \-b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \-boot-load-size 4 -boot-info-table -o $ISO_FILE ISOFilesystem/
}

function buildiso_mount_rootfs()
{
  echo "mount rootfs ..."
  sudo mount -o bind /dev $(pwd)/squashfs-root/dev  
  sudo mount -o bind /proc $(pwd)/squashfs-root/proc
  sudo mount -o bind /sys $(pwd)/squashfs-root/sys 
  sudo mount -o bind /dev/pts $(pwd)/squashfs-root/dev/pts
}

function buildiso_umount_rootfs()
{
  echo "umount rootfs ..."
  sudo umount $(pwd)/squashfs-root/dev/pts  
  sudo umount $(pwd)/squashfs-root/proc
  sudo umount $(pwd)/squashfs-root/sys 
  sudo umount $(pwd)/squashfs-root/dev
}


function buildiso_init_chroot()
{
  echo "init chroot ..."
  buildiso_mount_rootfs

  sudo chroot $(pwd)/squashfs-root /bin/bash

  buildiso_exit_chroot
}

function buildiso_exit_chroot()
{
  echo "exit chroot ..."
  buildiso_umount_rootfs
}

function buildiso_chroot_exec_default()
{
  echo "chroot exec default command ..."
  buildiso_mount_rootfs

#  sudo chroot $(pwd)/squashfs-root /bin/bash -c "[ -f /etc/proxychains.conf ] && rm /etc/proxychains.conf"

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '9.6' > /etc/debian_version"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "touch /root/init.txt"

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo -e 'net.core.default_qdisc=fq\nnet.ipv4.tcp_congestion_control=bbr' > /etc/sysctl.d/999-enabled-bbr.conf"

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo 'nameserver 114.114.114.114' > /etc/resolv.conf"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo 'nameserver 114.114.114.114' > /etc/resolvconf/resolv.conf.d/base"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo 'vm.overcommit_memory=1' >> /etc/sysctl.conf"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo 'net.core.somaxconn=1024' >> /etc/sysctl.conf"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo $NAS_VERSION >> /etc/nas_version"

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "sed 's/[a-z0-9\.-]*.debian.org/mirrors.163.com/g' -i /etc/apt/sources.list"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "sed 's#http://mirrors.163.com/ stretch/updates main contrib non-free#http://mirrors.163.com/debian stretch-updates main contrib non-free#g' -i /etc/apt/sources.list"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "sed 's/[a-z0-9\.-]*.debian.org/mirrors.163.com/g' -i /etc/apt/sources.list.d/openmediavault-kernel-backports.list"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "sed -ri '/AllowTcpForwarding/cAllowTcpForwarding yes' /etc/ssh/sshd_config"

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "apt update; apt install -y mysql-client pv curl htop net-tools vim byobu proxychains dnsutils mc jq git sshpass"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "sed -i 's/socks4 \t127.0.0.1 9050/socks5 124.193.118.116 57073/g' /etc/proxychains.conf"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '*/1 * * * * root  /usr/share/check_mon_health.sh' >> /etc/crontab"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '*/2 * * * * root /usr/first_init_online.sh' >>/etc/crontab"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '0 2 * * 0 root /usr/local/src/Casic-Client-DockerDeploy/data/run.sh -dball' >>/etc/crontab"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '0 4 * * * root /usr/local/src/Casic-Client-DockerDeploy/data/run.sh -dbadd' >>/etc/crontab"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '0 4 * * * root /usr/local/src/Casic-Client-DockerDeploy/data/run.sh -rb' >>/etc/crontab"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '0 0 * * * root find /data/backup/mysql/ -type f -a -mtime +14 -exec rm -rf {} \;' >>/etc/crontab"
  
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "chmod 0777 /srv/etc/config/common.yaml"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "systemctl enable ntp"


  buildiso_exit_chroot
  sudo cp -f /news/system-config/rc-local.service $(pwd)/squashfs-root/etc/systemd/system/
  sudo cp -f /news/system-config/rc.local $(pwd)/squashfs-root/etc/
  sudo cp -rf /news/news/packages/Casic-Client-DockerDeploy $(pwd)/squashfs-root/usr/local/src/
  sudo cp -rf /news/code/first_init_online.sh $(pwd)/squashfs-root/usr/
  sudo chmod 755  $(pwd)/squashfs-root/etc/rc.local
}

#function buildiso_chroot_exec_install_docker()
#{
#  echo "chroot exec apt upgrade command ..."
#  buildiso_mount_rootfs
#
#  sudo chroot $(pwd)/squashfs-root /bin/bash -c "proxychains sh -c 'curl -sSL https://get.docker.com/ | sh'"
#  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo 'DOCKER_OPTS=\"--registry-mirror=https://registry.docker-cn.com\"' >> /etc/default/docker"
#  sudo chroot $(pwd)/squashfs-root /bin/bash -c "proxychains sh -c 'curl -sSL https://raw.githubusercontent.com/docker/compose/master/script/run/run.sh > /usr/bin/docker-compose; chmod +x /usr/bin/docker-compose '"
#  sudo chroot $(pwd)/squashfs-root /bin/bash -c "proxychains sh -c 'curl -sSL https://raw.githubusercontent.com/ZZROTDesign/docker-clean/master/docker-clean > /usr/bin/docker-clean; chmod +x /usr/bin/docker-clean '" 
#   sudo cp $(pwd)/overlay/usr/share/openmediavault/mkconf/issue $(pwd)/squashfs-root/usr/share/openmediavault/mkconf/issue
#
#  buildiso_exit_chroot
#}
function buildiso_chroot_exec_install_docker()
{
  echo "chroot exec apt upgrade command ..."
  sudo cp -rf /news/packages/docker_install/ $(pwd)/squashfs-root/usr/
  buildiso_mount_rootfs

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "mv /usr/docker_install/* /usr/bin"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/usr/bin/docker.sh"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo 'DOCKER_OPTS=\"--registry-mirror=https://registry.docker-cn.com\"' >> /etc/default/docker"
   sudo cp $(pwd)/overlay/usr/share/openmediavault/mkconf/issue $(pwd)/squashfs-root/usr/share/openmediavault/mkconf/issue

  buildiso_exit_chroot
}
function buildiso_install_deb_package()
{
  buildiso_mount_rootfs
  echo "copy dbs/ to squashfs-root/temp ..."
  cp -R -f ../openmediavault/debs squashfs-root/temp 

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/usr/bin/dpkg -i /temp/wsdd_0.3-1_all.deb"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/usr/bin/dpkg -i /temp/openmediavault-keyring_1.0_all.deb"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/usr/bin/dpkg -i /temp/openmediavault_4.1.20-1_all.deb"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "rm -rf /temp"
  buildiso_exit_chroot
}

function buildiso_install_mon_package()
{
  buildiso_mount_rootfs
  echo "copy spl-mon-serv  to squashfs-root/mon-temp..."
  cp -R -f ../spl-mon-serv squashfs-root/mon-temp 
  cp -R -f /news/packages/ups_monitor_linux $(pwd)/squashfs-root/usr/local/src/
  cp -rf /news/packages/led_project $(pwd)/squashfs-root/usr/local/src/
  cp -rf /news/system-config/40-hidraw-do.rules $(pwd)/squashfs-root/etc/udev/rules.d/
  cp -rf /news/system-config/50-hidraw-chmod.rules $(pwd)/squashfs-root/etc/udev/rules.d/
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "mv -f /usr/local/src/ups_monitor_linux/ups_monitor.sh /etc/init.d/ups_monitor"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/bin/chmod +x /mon-temp/run.sh /mon-temp/spl-mon-serv_run"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/mon-temp/run.sh"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "rm -rf /mon-temp"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/bin/chmod +x /usr/local/src/led_project/install.sh"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "/usr/local/src/led_project/install.sh"
  buildiso_exit_chroot
}

function buildiso_chroot_exec_upgrade()
{
  echo "chroot exec apt upgrade command ..."
  buildiso_mount_rootfs

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "apt full-upgrade -y;apt remove linux-image-4.14.0 -y;"

  sudo cp $(pwd)/overlay/usr/share/openmediavault/mkconf/issue $(pwd)/squashfs-root/usr/share/openmediavault/mkconf/issue

  buildiso_exit_chroot
}

function buildiso_chroot_build_preprocessing()
{
  echo "chroot build before preprocessing ..."
  buildiso_mount_rootfs

  sudo chroot $(pwd)/squashfs-root /bin/bash -c "apt clean"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '' > /etc/resolv.conf"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "rm /root/.bash_history; rm /var/debconf/config.dat-old"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "rm /var/debconf/templates.dat-old; rm /var/lib/apt/lists/*"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '' > /var/log/apt/eipp.log.xz; echo '' > /var/log/apt/history.log"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "echo '' > /var/log/apt/term.log; echo '' > /var/log/dpkg.log"
  sudo chroot $(pwd)/squashfs-root /bin/bash -c "rm /var/cache/apt/pkgcache.bin; rm /var/cache/apt/srcpkgcache.bin"

  buildiso_exit_chroot
}

function buildiso_help()
{
  echo "buildiso utils 0.3 help:"
  echo "    all                     : simple build iso"
  echo "    clean                   : clean build system"
  echo "    -t, --tools             : install buildiso tools"
  echo "    -f, --first-rootfs      : uncompress first rootfs"
  echo "    -d, --delete-iso        : delete iso file"
  echo "    -c, --clean-rootfs      : clean rootfs"
  echo "    -o, --overlay-rootfs    : cp overlay to rootfs"
  echo "    -b, --build-rootfs      : build squashfs rootfs"
  echo "    -i, --build-iso         : build iso file"
  echo "    -s, --start-chroot      : start chroot"
  echo "    -e, --end-chroot        : end chroot"
  echo "    -idp                    : local install deb package"
  echo "    -imp                    : local install spl-mon-serv dev package"
  echo "    -cedc                   : chroot exec default command"
  echo "    -ceid                   : chroot exec install docker"
  echo "    -ceuc                   : chroot exec apt upgrade command"
  echo "    -cbpp                   : chroot build before preprocessing"
  echo "    -h, --help              : this help"
  exit 0
}

function show()
{
  echo "========================================"
  echo "  $1"
  echo "========================================"
  sleep 1
}

# 检测使用者为root用户
[ $(id -u) != "0" ] && { echo "${CFAILURE}错误: 你必须使用 root 权限用户运行这个脚本${CEND}"; exit 1; }

ARR=$@

[ -z "$ARR" ] && buildiso_help;

for arg in ${ARR[@]}
do
  case $arg in
    -h|--help)
      buildiso_help ;;
    -t|--tools)
      buildiso_install_utils ;;
    -f|--first-rootfs)
      buildiso_first_rootfs ;;
    -d|--delete-iso)
      buildiso_del_rootfs_iso ;;
    -c|--clean-rootfs)
      buildiso_clean_rootfs ;;
    -o|--overlay-rootfs)
      buildiso_overlay_rootfs ;;
    -b|--build-rootfs)
      buildiso_build_rootfs ;;
    -i|--build-iso)
      buildiso_build_iso ;;
    -s|--start-chroot)
      buildiso_init_chroot ;;
    -e|--end-chroot)
      buildiso_exit_chroot ;;
    -idp|--install-deb)
      buildiso_install_deb_package ;;
    -imp|--install-mon)
      buildiso_install_mon_package ;;
    -cedc)
      buildiso_chroot_exec_default ;;
    -ceid)
      buildiso_chroot_exec_install_docker ;;
    -ceuc)
      buildiso_chroot_exec_upgrade ;;
    -cbpp)
      buildiso_chroot_build_preprocessing ;;
    all)
      show "install host system utils"
      buildiso_install_utils
      show "uncompress to first rootfs"
      buildiso_first_rootfs
      show "overlay current rootfs files"
      buildiso_overlay_rootfs
      show "chroot: install target system tools"
      buildiso_chroot_exec_default
      show "chroot: upgrade apt newst package"
      buildiso_chroot_exec_upgrade
      show "chroot: upgrade install docker"
      buildiso_chroot_exec_install_docker 
      sleep 10
      show "chroot: install omv deb package"
      buildiso_install_deb_package
      show "chroot: install spl-mon-serv deb package"
      buildiso_install_mon_package
      show "chroot: clean install tmp files"
      buildiso_chroot_build_preprocessing
      show "build rootfs"
      buildiso_build_rootfs
      show "build iso"
      buildiso_build_iso ;;
    clean)
      show "clean tmp rootfs and iso"
      buildiso_umount_rootfs
      buildiso_clean_rootfs ;;
    *) buildiso_help ;;
  esac
done
