#!/bin/bash
#字体颜色
Green="\033[32m"
Red="\033[31m"
Yellow="\033[33m"
Font="\033[0m"

#提示信息
OK="${Green}[OK] "
Error="${Red}[Error] "
Yellow="${Yellow}[WARNING] "

rm -rf xray geo*.dat

#检查是否root用户
[ `id -u` != 0 ] && echo && echo -e "${Error}The current user isn't \"root\", please switch to the root user and execute the script again!${Font}" && echo && exit 1

[ "$(dpkg --list|grep wget)" == "" ] && echo -e "${OK}Installing wget, please wait...${Font}" && apt update &>/dev/null && apt install -y wget &>/dev/null

echo -e "${OK}Downloading xray, please wait...${Font}"
#curl -O --progress-bar $LINK
wget -q --show-progress https://github.com/lazymartin/scripts/releases/download/Last_release/xray_linux-x64 -O xray
[[ $? -ne 0 ]] && echo -e "${Error}Download xray failed, please check the network!${Font}" && exit

wget -q --show-progress https://github.com/lazymartin/scripts/releases/download/Last_release/geoip.dat
[[ $? -ne 0 ]] && echo -e "${Error}Download geoip.dat failed, please check the network!${Font}" && exit

wget -q --show-progress https://github.com/lazymartin/scripts/releases/download/Last_release/geosite.dat
[[ $? -ne 0 ]] && echo -e "${Error}Download geosite.dat failed, please check the network!${Font}" && exit

systemctl stop xray &>/dev/null

mkdir -p /usr/local/etc/xray
mkdir -p /usr/local/share/xray
mkdir -p /var/log/xray
touch /var/log/xray/error.log
touch /var/log/xray/access.log
chown nobody:adm /var/log/xray
chown nobody:nogroup /var/log/xray/*

mv xray /usr/local/bin/ && chmod +x /usr/local/bin/xray
mv {geoip.dat,geosite.dat} /usr/local/share/xray/

if [[ ! -f /usr/local/etc/xray/config.json ]]; then
  echo "{}" > /usr/local/etc/xray/config.json
  echo -e "${Yellow}
  The configuration file is empty, please complete the configuration, and then restart xray!!${Green}
  Configuration examples:
  https://github.com/XTLS/Xray-examples${Font}"
fi

[[ ! -f /usr/lib/systemd/system/xray.service ]] && wget -q --show-progress https://raw.githubusercontent.com/lazymartin/scripts/master/configurations/xray/xray.service -O /usr/lib/systemd/system/xray.service 

active_stat=`systemctl list-units --type=service --state=active |grep xray`
[[ -z ${active_stat} ]] && systemctl enable xray &>/dev/null

echo -e "${OK}The xray with latest commit has been installed!${Font}"

