#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

mkdir -p /etc/mosdns/rules/
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list cn -output /etc/mosdns/rules/geosite_cn.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list geolocation-cn -output /etc/mosdns/rules/geosite_geolocation-cn.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list apple-cn -output /etc/mosdns/rules/geosite_apple-cn.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list category-games@cn -output /etc/mosdns/rules/geosite_category-games@cn.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list category-games-cn -output /etc/mosdns/rules/geosite_category-games-cn.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list xiaomi-ads -output /etc/mosdns/rules/geosite_xiaomi-ads.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list netflix -output /etc/mosdns/rules/geosite_netflix.txt
geoview -type geoip -input /usr/share/v2ray/geoip.dat -list cn -output /etc/mosdns/rules/geoip_cn.txt

systemctl restart mosdns
