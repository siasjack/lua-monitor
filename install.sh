#!/bin/sh

check_lua_ver()
{
    lua -v > /tmp/.monitor.lua.ver 2>&1
    ver=$(cat /tmp/.monitor.lua.ver | cut -d ' ' -f 2 )
    [ -z "$ver" ] && echo "please install lua version >=5.1" && exit 1
    result=$(expr 5.1 \< $ver)
    if [ "1" != "$result" ];then
        echo "lua version is not satisfled,lua version should be >= 5.1"
        exit 1
    fi
	
}

check_lua_module()
{
	#echo "try to run monitor.lua to check module"
	lua src/monitor.lua 1>/tmp/monitor.tmp.log 2>&1 &
	sleep 1
	result=$(cat /tmp/monitor.tmp.log | grep 'no field package.preload')
	if [ -z "$result" ];then
		pid=$(ps aux  | grep 'src/monitor.lua' | grep -v grep  | awk '{print $2}')
		kill -9 $pid
	else
		echo "Dependent module is not installed:$result"
		echo "you can use luarocks cmd to install it"
		echo "==============Missing dependencies,run cmd=============="
		echo "sudo apt install luarocks  (for example ubuntu)"
		echo "sudo luarocks install lua-sockets"
		echo "sudo luarocks install lua-cjson"
		echo "sudo luarocks install luafilesystem"

		exit 2
	fi
	
}

check_lua_ver
echo "lua version check done"
check_lua_module

echo "we need sudo to install file to /usr/bin"
#cp files
sudo cp src/monitor.lua /usr/bin/monitor.lua
sudo cp src/monitor-ctrl.lua /usr/bin/monitor-ctrl.lua

sudo mkdir -p /etc/lua-monitor/conf.d
sudo cp src/conf.json /etc/lua-monitor/

mkdir -p /tmp/lua-monitor-demo
cp demo/die_loop.sh /tmp/lua-monitor-demo/
echo "install done!  Enjoy..."

echo "systemd-service-files dir has a systemd service,you can copy it to your systemd service direction"
echo "ex:/lib/systemd/system/ on ubuntu"
echo "Then you need run "
echo "sudo systemctl daemon-reload && sudo systemctl enable lua-monitor.service && sudo systemctl start lua-monitor.service"

