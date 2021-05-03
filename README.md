# Compile scripts
### `Reference`
[How to Use NGINX as an HTTPS Forward Proxy Server](https://www.alibabacloud.com/blog/how-to-use-nginx-as-an-https-forward-proxy-server_595799)

[NaiveProxy + Caddy 2](https://www.oilandfish.com/posts/naiveproxy-caddy-2.html)

[aria2 compile script](https://github.com/q3aql/aria2-static-builds)

# [DD system script](https://github.com/veip007/dd)
### `Useage`
    The original system recommends using ubuntu 18.04
```
bash <(wget --no-check-certificate -qO- 'https://raw.githubusercontent.com/lazymartin/scripts/master/dd.sh') -d 10 -v 64 -p 'xxx' -a --mirror 'http://mirrors.aliyun.com/debian'

    Installation parameter description：  

        -d 10     -->  diban 10  
        -v 64     -->  64 bit  
        -p 'xxx'  -->  setup password
        -a        -->  auto install  
        --mirror  -->  mirror site  
```
