#!/usr/bin/lua
socket = require"socket"
cjson = require "cjson"
lfs = require("lfs")

G_timer_tasks={}
G_custom_conf={}
--lua编写的监控程序，仿照C的monitor程序实现
--实现秒级监控文件变化、进程守护等功能
function sleep(n)
    socket.select(nil, nil, n)
end

function timer_task_add(name,func_time)
    if name and type(func_time)=="table" and func_time.func and type(func_time.func) == "function" and func_time.period then
        func_time["task_info"] = {}
        func_time["task_info"]["__last_call_time"] = 0
        func_time["task_info"]["stop"] = false
        G_timer_tasks[name] = func_time
    else
        debug("err","timer task add error input para!")
    end
end

function timer_task_del(name)
    if name then
        G_timer_tasks[name] = nil
    end
end
function timer_task_stop(name)
    if name == nil then
        for n,task in pairs(G_timer_tasks) do
            task["task_info"]["stop"] = true
        end
        return
    end
    if name and G_timer_tasks[name] then
        G_timer_tasks[name]["task_info"]["stop"] = true
    end
end

function timer_task_start(name)
    if name == nil then
        for n,task in pairs(G_timer_tasks) do
            task["task_info"]["stop"] = false
        end
        return
    end
    if name and G_timer_tasks[name] then
        G_timer_tasks[name]["task_info"]["stop"] = false
    end
end

function do_timer_task()
    local now = os.time()
    if last_call_time == nil then
        last_call_time = 0
    end
    if now - last_call_time >= 1 then
        --print_with_time("G_timer_tasks num = "..#G_timer_tasks)
        for name,task in pairs(G_timer_tasks) do
            if not task.task_info.stop and (now-task["task_info"]["__last_call_time"]) >= task.period then
                task.func(task.args)
                task["task_info"]["__last_call_time"]= now
            end
        end
        last_call_time = now
    end

end

function cjson_decode_safe(str)
    if type(str) ~= "string" then
        return nil
    end
    local res,tab = pcall(cjson.decode,str)
     if res == false then
         return nil
     else
         return tab
     end
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
--just append msg to a file
function appendData2file(filename, data_string)
    local file = io.open(filename, "a+")
    if file then
        file:write(data_string)
        file:close()
        return true
    end
    return false
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
--split a string
function split(szFullString, szSeparator, index)
    local nFindStartIndex = 1 
    local nSplitIndex = 1 
    local nSplitArray = {}
    
    while true do
        local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
        if not nFindLastIndex then
    
            nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
            if nSplitIndex == index then
                return nSplitArray[nSplitIndex]
            end 
            break
        end 
    
        nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
        if nSplitIndex == index then
            return nSplitArray[nSplitIndex]
        end 
        nFindStartIndex = nFindLastIndex + string.len(szSeparator)
        nSplitIndex = nSplitIndex + 1 
    end 
    return nSplitArray
end

function get_mypid()
    local stat = readfile("/proc/self/stat")
    stat = split(stat, " ", 1)
    return tonumber(stat)
end

function start_conf_by_name(name)
    timer_task_start(name)
    if name then
        G_custom_conf[name].stop = false
    else
        for n,conf in pairs(G_custom_conf) do
            conf.stop = false
        end
    end
end
function stop_conf_by_name(name)
    timer_task_stop(name)
    if name then
        G_custom_conf[name].stop = true
    else
        for n,conf in pairs(G_custom_conf) do
            conf.stop = true
        end
    end
    
end
function get_tab_len(t)
    local cnt = 0
    if(type(t) ~= "table" )  then 
        return 0 
    end
    for k,v in pairs(t) do
        cnt = cnt + 1
    end
    return cnt
end

MY_VERSION="1.0.0"
CTRL_RSP_FILE="/tmp/.lua-monitor.rsp"
function print_conf_status()
    --writeData2file(CTRL_RSP_FILE,"lua monitor status,version "..MY_VERSION.."\n")
    writeData2file(CTRL_RSP_FILE,"[\n") 
    local len = get_tab_len(G_custom_conf)
    local first_ele = true
    local i = 1
    for name,conf in pairs(G_custom_conf) do
        local c = {}
        c.name = name
        c.trigger_times = conf.trigger_times or 0
        c.type = conf.type
        c.stop = conf.stop or false
        if conf.start_time then
            c.run_time =  os.time() - conf.start_time
        end
        c.last_state = conf.last_state 
        appendData2file(CTRL_RSP_FILE,cjson.encode(c)) 
        if i < len then
            appendData2file(CTRL_RSP_FILE,",\n")
        end
        i=i+1
    end
    appendData2file(CTRL_RSP_FILE,"\n]\n") 
end
--ctrl
function process_ctrl_msg(ctrl)

    if ctrl.cmd == "reload" then
        --killall process
        for n, conf in pairs(G_custom_conf) do
            if conf.type == "process" then
                local pid = readfile(conf.pidfile)
                os.execute("kill -9 "..pid)
                debug("warn","kill process "..conf.name)
            end
        end
        G_custom_conf={}
        G_timer_tasks={}
        read_default_conf()
        walk_all_conf_json(G_conf.include)
    elseif ctrl.cmd == "start" then
        if not ctrl.para or not G_custom_conf[ctrl.para] then
            debug("err","start conf name is err!")
            os.exit()
        end
        start_conf_by_name(ctrl.para)
        writeData2file(CTRL_RSP_FILE,"start "..ctrl.para.." done")
        debug("info","start "..ctrl.para.." done")
    elseif ctrl.cmd == "stop" then
        if not ctrl.para or not G_custom_conf[ctrl.para] then
            debug("err","start conf name is err!")
            os.exit()
        end
        stop_conf_by_name(ctrl.para)
        writeData2file(CTRL_RSP_FILE,"stop "..ctrl.para.." done")
        debug("info","stop "..ctrl.para.." done")
    elseif ctrl.cmd == "stop_all" then
        stop_conf_by_name()
        writeData2file(CTRL_RSP_FILE,"stop all done")
        debug("info","stop all done")
    elseif ctrl.cmd == "start_all" then
        start_conf_by_name()
        writeData2file(CTRL_RSP_FILE,"start all done")
        debug("info","start all done")
    elseif ctrl.cmd == "status" then
        print_conf_status()
        debug("info","rsp status done" )
    end
    
end

--ctrl msg:
--{"cmd":"reload/start/stop/stop_all/restart/start_all/status","para":"test"}
function check_ctrl_msg()
    CTRL_MSG_FILE="/tmp/.lua-monitor.ctrl"
    local json = readfile(CTRL_MSG_FILE)
    if json then
        local ctrl = cjson_decode_safe(json)
        if(type(ctrl) == "table") then
            process_ctrl_msg(ctrl)
            os.remove(CTRL_MSG_FILE)
        end
    end
end

debug_level={err=3,warn=2,info=1}

function debug(level,s, ...)
    if not debug_level[level] or not G_conf.debug_level or not debug_level[G_conf.debug_level] or debug_level[level] < debug_level[G_conf.debug_level] then
        return
    end
    s = tostring(s)
    local date = os.date("%m%d %H:%M:%S")
    if G_conf.debug_file then
        local file = io.open(G_conf.debug_file, "a")
        file:write(level.."[" .. date .. "] " .. s:format(...) .. "\n")
        file:close()
    else
        print(level.."[" .. date .. "] " .. s:format(...))
    end
end

function task_cb_process(conf)
    if not G_custom_conf[conf.name]["pid"] then
        G_custom_conf[conf.name]["pid"] = tonumber(readfile(conf.pidfile))
    end
    --print("check process stat file ".."/proc/"..tostring(G_custom_conf[conf.name]["pid"]).."/stat")
    local stat = readfile("/proc/"..tostring(G_custom_conf[conf.name]["pid"]).."/stat")
    if stat then
        local stat_tab = split(stat," ")
        if stat_tab[3] ~= "Z" and string.upper(stat_tab[3]) ~= "X" then
            G_custom_conf[conf.name]["state"] = "running"
            if not G_custom_conf[conf.name]["start_time"] then
                G_custom_conf[conf.name]["start_time"] = os.time()
            end
            return true
        else
            debug("err","process "..conf.name.." stat is zombie or dead!!")
        end
    end
    --kill old
    os.execute("kill -9 "..tostring(G_custom_conf[conf.name]["pid"]))
    --process has die,restart it in background
    os.execute(G_custom_conf[conf.name]["cmd"].." &")
    G_custom_conf[conf.name]["trigger_times"] = (G_custom_conf[conf.name]["trigger_times"] or 0) + 1
    G_custom_conf[conf.name]["start_time"] = os.time()   --启动时间
    G_custom_conf[conf.name]["pid"] = nil
    debug("warn","process "..conf.name.." restart!")
end

function task_cb_file(conf_tab)
    local state = ""
    if conf_tab.check == "modification" or conf_tab.check == "size"  then
        local file_attr = lfs.attributes(conf_tab.path)
        if type(file_attr) == "table" then
            if file_attr.mode ~= "file" then
                debug("err",conf_tab.path .." is not a file")
                return
            end
            state = file_attr[conf_tab.check]
        else
            state = "not_found"
            debug("err",conf_tab.name.." " .. conf_tab.path .." not found")
        end
    elseif conf_tab.check == "md5" then
        debug("err","not support:When calculating the md5 of a large file, it may take too long time!")
        os.exit()
    else
        debug("err","not support check method!exit...")
        os.exit()
    end

    if not G_custom_conf[conf_tab.name]["last_state"] then
        G_custom_conf[conf_tab.name]["last_state"] = state
        return
    end

    if G_custom_conf[conf_tab.name]["last_state"] ~= state then
        G_custom_conf[conf_tab.name]["last_state"] = state
        G_custom_conf[conf_tab.name]["trigger_times"] = (G_custom_conf[conf_tab.name]["trigger_times"] or 0) + 1
        os.execute(conf_tab.cmd.." &")
        debug("warn",conf_tab.name.." trigger")
    end
end
function task_cb_dir(conf_tab)
    local state = ""
    if conf_tab.check == "modification" then
        local file_attr = lfs.attributes(conf_tab.path)
        if type(file_attr) == "table" then
            if file_attr.mode ~= "directory" then
                debug("err",conf_tab.path .." is not a directory")
                return
            end
            state = file_attr[conf_tab.check]
        else
            state = "not_found"
            debug("err",conf_tab.path .." not found")
        end
    end

    if not G_custom_conf[conf_tab.name]["last_state"] then
        G_custom_conf[conf_tab.name]["last_state"] = state
        return
    end

    if G_custom_conf[conf_tab.name]["last_state"] ~= state then
        G_custom_conf[conf_tab.name]["last_state"] = state
        G_custom_conf[conf_tab.name]["trigger_times"] = (G_custom_conf[conf_tab.name]["trigger_times"] or 0) + 1
        os.execute(conf_tab.cmd.." &")
        debug("warn",conf_tab.name.." trigger")
    end
end

function task_cb_timer(conf_tab)
    G_custom_conf[conf_tab.name]["last_state"] = os.time()
    G_custom_conf[conf_tab.name]["trigger_times"] = (G_custom_conf[conf_tab.name]["trigger_times"] or 0) + 1
    os.execute(conf_tab.cmd.." &")
    debug("warn",conf_tab.name.." trigger")
end

--{"name":"demo","type":"process","cmd":"/usr/bin/test","pidfile":"/var/run/test.pid","period":10}
--{"name":"demo_file","type":"file","check":"modification/md5/size","cmd":"/usr/bin/file_has_change.cb","period":10,"path":"/tmp/haha"}
--{"name":"demo_dir","type":"dir","check":"modification","cmd":"/usr/bin/dir_has_change.cb","period":10,"path":"/tmp/dir_test"}
--{"name":"demo_timer","type":"timer","cmd":"/usr/bin/timer_exec.sh","period":10}
function custom_conf_check(conf_tab)
    if not conf_tab.name or not conf_tab.period or not conf_tab.type then
        debug("err","conf err:"..tostring(conf_tab.name).." interval:"..tostring(conf_tab.period))
        os.exit()
    end
    if conf_tab.type == "process" and ( not conf_tab.cmd or not conf_tab.pidfile ) then
        debug("err","conf "..conf_tab.name.." cmd or pidfile lost")
        os.exit()
    elseif conf_tab.type == "file" and (not conf_tab.check or not conf_tab.cmd or not conf_tab.path) then
        debug("err","conf "..conf_tab.name.." check or cmd lost")
        os.exit()
    elseif conf_tab.type == "dir" and (not conf_tab.check or not conf_tab.cmd) then
        debug("err","conf "..conf_tab.name.." check or cmd lost")
        os.exit()
    elseif conf_tab.type == "timer" and (not conf_tab.cmd) then
        debug("err","conf "..conf_tab.name.." cmd lost")
        os.exit()
    end
    return true
end

function custom_conf_add_to_task(conf_tab)
    --所有任务放入全局变量，便于统计信息和获取状态
    G_custom_conf[conf_tab.name] =conf_tab
    if conf_tab.type == "process" then
        debug("info","conf "..conf_tab.name.." adding")
        timer_task_add(conf_tab.name,{func=task_cb_process,period=tonumber(conf_tab.period),args=conf_tab})
    elseif conf_tab.type == "file" then
        debug("info","conf "..conf_tab.name.." adding")
        timer_task_add(conf_tab.name,{func=task_cb_file,period=tonumber(conf_tab.period),args=conf_tab})
    elseif conf_tab.type == "dir" then
        debug("info","conf "..conf_tab.name.." adding")
        timer_task_add(conf_tab.name,{func=task_cb_dir,period=tonumber(conf_tab.period),args=conf_tab})
    elseif conf_tab.type == "timer" then
        debug("info","conf "..conf_tab.name.." adding")
        timer_task_add(conf_tab.name,{func=task_cb_timer,period=tonumber(conf_tab.period),args=conf_tab})
    end
end

function walk_all_conf_json(include_tab)
    if type(include_tab) ~= "table" then
        return
    end
    for _,conf_dir in ipairs(include_tab) do
        for file in lfs.dir(conf_dir) do
            if file ~= "." and file ~= ".." then
                local f = conf_dir.."/"..file
                debug("info","\t parsing "..f.." <=")
                local conf = readfile(f)
                local conf_tab = cjson.decode(conf)
                if type(conf_tab) == "table" then
                    custom_conf_check(conf_tab)
                else
                    debug("err","conf file "..f.." not a valid json,exit...")
                    os.exit()
                end
                custom_conf_add_to_task(conf_tab)
            end
        end
    end
end

--main
print("monitor start version:"..MY_VERSION)
--{"include":["dir3","dir1","dir2"],"pidfile":"/var/run/lua-monitor.pid","debug_level":"info/err/warn","debug_file":"/dev/null"}
DEFAULT_CONF_FILE="/etc/lua-monitor/conf.json"
G_conf ={
    include={"/etc/lua-monitor/conf.d"},
    pidfile="/var/run/lua-monitor.pid",
    debug_level="info",
    debug_file=nil
}
function read_default_conf()
    local conf = readfile(DEFAULT_CONF_FILE)
    local conf_tab = cjson_decode_safe(conf)
    if type(conf_tab) == "table" then
        G_conf.include = conf_tab.include or G_conf.include
        G_conf.pidfile = conf_tab.pidfile or G_conf.pidfile 
        G_conf.debug_level = conf_tab.debug_level or G_conf.debug_level 
        G_conf.debug_file = conf_tab.debug_file or G_conf.debug_file 
    else
        debug("warn","conf file "..DEFAULT_CONF_FILE.." not a valid json,use default conf")
    end
end
read_default_conf()
writeData2file(G_conf.pidfile,tostring(get_mypid()))
walk_all_conf_json(G_conf.include)


while 1 do
    do_timer_task()
    check_ctrl_msg()
    
    sleep(1)
end





