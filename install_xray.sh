#!/bin/bash
# font color
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Font="\033[0m"

# message type
OK="${Green}[OK] "
Error="${Red}[Error] "
Yellow="${Yellow}[WARNING] "

if [[ -z ${webdav_link} ]]; then
  download_link="https://github.com/lazymartin/scripts/releases/download/Last_release/"
  config_link="https://raw.githubusercontent.com/lazymartin/scripts/master/configurations/xray/"
  else
  download_link="--http-user=${webdav_username} --http-passwd=${webdav_password} ${webdav_link}"
  config_link="--http-user=${webdav_username} --http-passwd=${webdav_password} ${webdav_link}"
fi

if [[ -f /usr/local/bin/xray ]]; then
  install_type="UPGRADED"
  else
  install_type="INSTALLED"
fi

#Check if root user
[ `id -u` != 0 ] && echo && echo -e "${Error}The current user isn't \"root\", please switch to the root user and execute the script again!${Font}" && echo && exit 1

system_type=`cat /etc/issue|head -n 1|awk '{print $1}'` # get system type
arch_type=`uname -m` # get arch type

if [[ ${arch_type} = "x86_64" ]]; then
  xray_file="xray_linux_x86_64"
elif [[ ${arch_type} = "aarch64" ]]; then
  xray_file="xray_linux_arm64_v8a"
else
  echo && echo -e "${Error}Only supports x86_64 or aarch64 architecture!!${Font}" && echo && exit 1
fi

if [[ "${system_type}" = "Debian" || "${system_type}" = "Ubuntu" || "${system_type}" = "Armbian" ]]; then
  echo ""
  else
  echo && echo -e "${Error}Only supports Debian or Ubuntu system!!${Font}" && echo && exit 1
fi


rm -rf xray geo*.dat

[ "$(dpkg --list|grep wget)" == "" ] && echo -e "${OK}Installing wget, please wait...${Font}" && apt update &>/dev/null && apt install -y wget &>/dev/null

echo -e "${OK}Downloading xray, please wait...${Font}"
#curl -O --progress-bar $LINK
wget -q --show-progress ${download_link}${xray_file} -O xray
[[ $? -ne 0 ]] && echo -e "${Error}Download xray failed, please check network connection!${Font}" && exit

wget -q --show-progress ${download_link}geoip.dat
[[ $? -ne 0 ]] && echo -e "${Error}Download geoip.dat failed, please check network connection!${Font}" && exit

wget -q --show-progress ${download_link}geosite.dat
[[ $? -ne 0 ]] && echo -e "${Error}Download geosite.dat failed, please check network connection!${Font}" && exit

systemctl stop xray &>/dev/null

mkdir -p /usr/local/etc/xray
mkdir -p /usr/local/share/xray
mkdir -p /var/log/xray
touch /var/log/xray/error.log
touch /var/log/xray/access.log
chown www-data:adm /var/log/xray
chown www-data:www-data /var/log/xray/*
mv xray /usr/local/bin/ && chmod +x /usr/local/bin/xray
mv {geoip.dat,geosite.dat} /usr/local/share/xray/

if [[ ! -f /usr/local/etc/xray/config.json ]]; then
  echo "{}" > /usr/local/etc/xray/config.json
  echo -e "${Yellow}
  The configuration file is empty, please complete the configuration, and then restart xray!!${Green}
  Configuration examples:
  https://github.com/XTLS/Xray-examples${Font}"
fi

[[ ! -f /usr/lib/systemd/system/xray.service ]] && wget -q --show-progress ${config_link}xray.service -O /usr/lib/systemd/system/xray.service 

active_stat=`systemctl list-units --type=service --state=active |grep xray`
[[ -z ${active_stat} ]] && systemctl enable xray &>/dev/null

echo -e "${OK}The xray with latest commit has been ${install_type}!${Font}"
