#!/usr/bin/lua

local cjson = require("cjson")
socket = require"socket"
--useage 
--minitor-ctrl.lua reload/status/start/stop/start_all/stop_all [conf_name]


function sleep(n)
    socket.select(nil, nil, n)
end

--if file is exist return true ,else return false
function file_exists(path)
    local file = io.open(path, "rb")
    if file then file:close() end
    return file ~= nil
end
--just save data to a file
function writeData2file(filename, data_string)
    local file = io.open(filename, "w")
    if file then
        if data_string == nil then data_string = "" end
        file:write(data_string)
        file:close()
        return true
    end
    return false
end
--read file all content
function readfile(filename)
    local file = io.open(filename, "r")
    local data = nil
    if file then
        data = file:read("*all")
        file:close()
    end
    return data
end
CTRL_MSG_FILE="/tmp/.lua-monitor.ctrl"
CTRL_RSP_FILE="/tmp/.lua-monitor.rsp"
local ctrl = {}
if arg[1] == "reload" or arg[1]=="status" or arg[1] == "start_all" or arg[1] == "stop_all" then
    ctrl.cmd = arg[1]
elseif  arg[1] == "start" or arg[1] == "stop" then
    if arg[2] then
        ctrl.cmd = arg[1]
        ctrl.para = arg[2]
    else
        print("error: start/stop must have conf name")
        os.exit()
    end
else
    print("error: arg unkown "..arg[1])
    os.exit()
end

local start_time = os.time()
while true do
    if file_exists(CTRL_MSG_FILE) then
        sleep(1)
        print("waitting...")
    else
        break
    end
    if os.time() - start_time > 10 then
        print("ctrl error:timeout")
        os.exit()
    end
end

os.remove(CTRL_RSP_FILE)
start_time = os.time()
writeData2file(CTRL_MSG_FILE,cjson.encode(ctrl))
while true do
    local rsp = readfile(CTRL_RSP_FILE)
    if rsp then
        print(rsp)
        break
    end
    if os.time() - start_time > 10 then
        print("wait response error:timeout")
        os.exit()
    end
    sleep(1)
end
