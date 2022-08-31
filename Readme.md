## 说明
本脚本主要灵感来自C实现的monit程序和python实现的supervisor，属于monit程序的超级缩减版  
功能会逐步添加，丰富。  
当前功能有限，但是对于一般的网关路由器来说可以覆盖一部分的需求，实现秒级监控进程和文件
本程序的所有配置文件均使用json格式，简单易于理解


## 主要功能
1. 根据pid文件守护指定进程
2. 定时器：定时执行指定的命令或脚本
3. 监控文件及文件夹的修改时间、文件大小，如有改变则调用指定命令或脚本

## 系统依赖
依赖的软件有：  
- lua 5.1及以上
- luarocks
- lua-sockets
- lua-cjson
- luafilesystem  
**安装依赖软件及第三方库，以Ubuntu为例**
```
apt install lua
apt install luarocks
luarocks install lua-sockets
luarocks install lua-cjson
luarocks install luafilesystem
```

## 注意事项
- 为了保证本程序的稳定性、时效性，本程序所调用的所有命令均会增加&，使其后台运行

## Ubuntu等Linux系统安装方法
```
git clone https://gitee.com/siasjack/lua-monitor.git
cd lua-monitor
sudo ./install.sh
```
### 安装systemctl服务
```
sudo cp systemd-service-files/lua-monitor.service /lib/systemd/system/
sudo systemctl daemon-reload 
sudo systemctl enable lua-monitor.service 
sudo systemctl start lua-monitor.service
``` 

## openwrt软件包安装方法
```
cd ${OPENWRT_SDK_path}
cd package/utils
git clone https://gitee.com/siasjack/lua-monitor.git
cd ${OPENWRT_SDK_path}
make menuconfig 

```

## 更新日志
### V1.1.0  
1. 增加日志切割功能，依赖logrotate软件包，仅当任务为process时才会用到日志切割，请参见die_loop.conf配置
2. 解决openwrt下编译出错的问题
