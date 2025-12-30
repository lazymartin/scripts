#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

mkdir -p /etc/mosdns/rules/
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list cn -output /etc/mosdns/rules/geosite_cn.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list category-ads-all -output /etc/mosdns/rules/geosite_category-ads-all.txt
geoview -type geosite -input /usr/share/v2ray/geosite.dat -list netflix,primevideo,disney -output /etc/mosdns/rules/streaming_media_domains.txt

geoview -type geoip -input /usr/share/v2ray/geoip.dat -list cn -output /etc/mosdns/rules/geoip_cn.txt

systemctl restart mosdns
