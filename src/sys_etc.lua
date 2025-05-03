--[[-----------------------------------------------------------------------------
  作者： dmzn@163.com 2025-04-28
  描述： etc终端业务
-------------------------------------------------------------------------------]]
local mqttc = nil
local mqtt_host = "123.56.150.117"
local mqtt_port = 8083
local mqtt_ssl = false

local client_id = device_id
local user_name = "user_etc"
local password = "user_etc"

local topic_pub = string.format(Mqtt_Topic_Pub, device_id)
local topic_sub = string.format(Mqtt_Topic_Sub, device_id)
local topic_srv = Mqtt_Topic_Srv

--[[
  date: 2025-05-03
  parm: event,日志;remote,是否发送远程
  desc: 打印运行日志
--]]
function Show_log(event, remote, level)
  if (#event) < 1 then -- empty
    return
  end

  level = (level ~= nil) and level or log.LOG_INFO --默认: info
  remote = (remote ~= nil) and remote or false     --默认: 仅本地

  if level == log.LOG_INFO then
    log.info(event)
  end

  if level == log.LOG_WARN then
    log.warn(event)
  end

  if level == log.LOG_ERROR then
    log.error(event)
  end

  if remote and mqttc and mqttc:ready() then --mqtt connected
    event = string.format('{"cmd": 3, "log": "%s"}', event)
    sys.publish(Status_Mqtt_PubData, topic_pub, event, 0)
  end
end

--[[
  date: 2025-05-03
  parm: data,数据
  desc: 向 topic 发送数据
--]]
function Mqtt_send(data, topic, qos)
  if (#data) < 1 then -- empty
    return
  end

  if mqttc and mqttc:ready() then --mqtt connected
    topic = (topic ~= nil) and topic or topic_pub
    qos = (qos ~= nil) and qos or 0
    sys.publish(Status_Mqtt_PubData, topic, data, qos)
  end
end

sys.taskInit(function ()
  -- 等待联网
  local ret, device_id = sys.waitUntil(Status_Net_Ready)

  -- 生成mqtt参数
  client_id = device_id
  topic_pub = string.format(Mqtt_Topic_Pub, device_id)
  topic_sub = string.format(Mqtt_Topic_Sub, device_id)

  log.info("mqtt", "pub", topic_pub)
  log.info("mqtt", "sub", topic_sub)

  if mqtt == nil then
    while 1 do
      sys.wait(1000)
      log.info("bsp", "本bsp未适配mqtt库, 请查证")
    end
  end

  -------------------------------------------------------------------------------
  mqttc = mqtt.create(nil, mqtt_host, mqtt_port, mqtt_ssl)
  mqttc:auth(client_id, user_name, password) -- 认证
  mqttc:keepalive(1000)                      -- 心跳间隔
  mqttc:autoreconn(true, 5000)               -- 自动重连机制

  local will = string.format('{"cmd": 2, "id": "%s"}', device_id)
  mqttc:will(topic_pub, will, 1, 1) --离线通知

  mqttc:on(function (mqtt_client, event, data, payload)
    if event == "conack" then
      -- mqtt_client:subscribe(topic_sub)--单主题订阅
      mqtt_client:subscribe({ [topic_sub] = 1, [topic_srv] = 1 }) --多主题订阅

      log.info("MQTT,连接成功.")
      sys.publish(Status_Mqtt_Connected)

      local online = string.format('{"cmd": 1, "id": "%s"}', device_id)
      mqtt_client:publish(topic_pub, online, 1, 1) --上线通知
    elseif event == "recv" then
      sys.publish(Status_Mqtt_SubData, data, payload)
      -- elseif event == "sent" then
      -- log.info("mqtt", "sent", "pkgid", data)
      -- elseif event == "disconnect" then
      -- 非自动重连时,按需重启mqttc
      -- mqtt_client:connect()
    end
  end)

  log.info("MQTT,连接中...")
  mqttc:connect()
  sys.waitUntil(Status_Mqtt_Connected)

  -------------------------------------------------------------------------------
  while true do
    local ret, topic, data, qos = sys.waitUntil(Status_Mqtt_PubData, 300000)
    if ret then
      -- 关闭本while循环
      if topic == "close" then break end
      mqttc:publish(topic, data, qos)
    end
  end

  mqttc:close()
  mqttc = nil
end)


-------------------------------------------------------------------------------
---
---
--处理: 服务器 -> 设备数据
sys.taskInit(function ()
  while true do
    ::continue::
    local ret, topic, data = sys.waitUntil(Status_Mqtt_SubData)
    local srv, err = json.decode(data)

    if srv == nil or type(srv) ~= "table" or srv.cmd == nil then
      Show_log("MQTT: 无效的命令格式(json)", true)
      goto continue
    end

    if srv.cmd == Cmd_Get_SysInfo then --运行信息
      local event = string.format('{"cmd": 4, "sys":, "%s"}', json.encode(Sys_Info()))
      sys.publish(Status_Mqtt_PubData, topic_pub, event, 0)
      goto continue
    end

    if srv.cmd == Cmd_OTA_Start then --OTA
      sys.publish(Status_OTA_Update)
      goto continue
    end
  end
end)
