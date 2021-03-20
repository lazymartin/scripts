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

#检查是否root用户
[ `id -u` != 0 ] && echo && echo -e "${Error}The current user isn't \"root\", please switch to the root user and execute the script again!${Font}" && echo && exit 1

REPO_NAME="v2fly/v2ray-core"
APP_NAME="v2ray"
KEYWORD1="linux-64"

echo -e "${OK}Install download tools for $APP_NAME, please wait...${Font}"
apt update &>/dev/null && apt install -y unzip curl wget &>/dev/null

echo -e "${OK}Getting latest release of $APP_NAME, please wait...${Font}"
FILE_NAME=`curl -s https://api.github.com/repos/$REPO_NAME/releases/latest|grep $KEYWORD1|awk -F "\"" 'NR==1 {print $4}'`
DOWNLOAD_LINK=`curl -s https://api.github.com/repos/$REPO_NAME/releases/latest|grep $KEYWORD1|awk -F "\"" 'NR==2 {print $4}'`
FILE_VER=`curl -s https://api.github.com/repos/$REPO_NAME/releases/latest|grep tag_name|awk -F "\"" '{print $4}'`

echo -e "${OK}Downloading $APP_NAME, please wait...${Font}"
#curl -O --progress-bar $LINK
wget -q $DOWNLOAD_LINK --show-progress -O $FILE_NAME
[[ $? -ne 0 ]] && echo -e "${Error}Download error, please check the network!${Font}" && exit
[[ -n `echo $FILE_NAME |grep zip` ]] && unzip -qo $FILE_NAME -d ./$APP_NAME
[[ $? -ne 0 ]] && echo -e "${Error}Unzip error, please download again!${Font}" && exit
# [[ -n `echo $FILE_NAME |grep tar` ]] && tar xf $FILE_NAME && FILE_NAME=`echo $FILE_NAME|sed "s/.tar.*$//g"`

systemctl stop $APP_NAME &>/dev/null
mkdir -p /usr/local/etc/$APP_NAME && mkdir -p /usr/local/share/$APP_NAME
cd ./$APP_NAME
cp $APP_NAME /usr/local/bin/
[[ ! -f /usr/local/etc/$APP_NAME/config.json ]] && echo "{}" > /usr/local/etc/$APP_NAME/config.json
cp geoip.dat geosite.dat /usr/local/share/$APP_NAME/
chmod +x /usr/local/bin/$APP_NAME

echo "[Unit]
Description=${APP_NAME} Service
Documentation=https://github.com/${REPO_NAME}
After=network.target nss-lookup.target

[Service]
User=nobody
Type=simple
StandardError=journal
NoNewPrivileges=true
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
ExecStart=/usr/local/bin/$APP_NAME run -config /usr/local/etc/$APP_NAME/config.json
ExecReload=/bin/kill -HUP \$MAINPID
Restart=on-failure
RestartSec=1s
RestartPreventExitStatus=23
LimitNPROC=500
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target" > /usr/lib/systemd/system/$APP_NAME.service

cd .. && rm -rf ./$APP_NAME $FILE_NAME
echo -e "${OK}The $APP_NAME $FILE_VER installation is completed!
${Yellow}Please complete configuration file and execute the command:${Font}
systemctl enable $APP_NAME
systemctl start $APP_NAME"
