--[[-----------------------------------------------------------------------------
  作者： dmzn@163.com 2025-04-28
  描述： etc终端业务
-------------------------------------------------------------------------------]]
local mqttc = nil
local mqtt_host = "123.56.150.117"
local mqtt_port = 8083
local mqtt_isssl = false

local client_id = device_id
local user_name = "user_etc"
local password = "user_etc"

local topic_pub = string.format(Mqtt_Topic_Pub, device_id)
local topic_sub = string.format(Mqtt_Topic_Sub, device_id)
local topic_srv = Mqtt_Topic_Srv

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
  mqttc = mqtt.create(nil, mqtt_host, mqtt_port, mqtt_isssl)
  mqttc:auth(client_id, user_name, password)    -- 认证
  mqttc:keepalive(240)                          -- 心跳间隔
  mqttc:autoreconn(true, 3000)                  -- 自动重连机制
  mqttc:will(topic_pub, Mqtt_Client_Will, 1, 1) --离线通知

  mqttc:on(function (mqtt_client, event, data, payload)
    if event == "conack" then
      -- mqtt_client:subscribe(topic_sub)--单主题订阅
      mqtt_client:subscribe({ [topic_sub] = 1, [topic_srv] = 1 }) --多主题订阅

      log.info("MQTT,连接成功.")
      sys.publish(Status_Mqtt_ConnAck)
      mqtt_client:publish(topic_pub, Mqtt_Client_Online, 1, 1) --上线通知
    elseif event == "recv" then
      log.info("mqtt", "downlink", "topic", data, "payload", payload)
      sys.publish("mqtt_payload", data, payload)
    elseif event == "sent" then
      -- log.info("mqtt", "sent", "pkgid", data)
      -- elseif event == "disconnect" then
      -- 非自动重连时,按需重启mqttc
      -- mqtt_client:connect()
    end
  end)

  log.info("MQTT,连接中...")
  mqttc:connect()
  sys.waitUntil(Status_Mqtt_ConnAck)

  -------------------------------------------------------------------------------
  while true do
    -- 演示等待其他task发送过来的上报信息
    local ret, topic, data, qos = sys.waitUntil("mqtt_pub", 300000)
    if ret then
      -- 提供关闭本while循环的途径, 不需要可以注释掉
      if topic == "close" then break end
      mqttc:publish(topic, data, qos)
    end
    -- 如果没有其他task上报, 可以写个空等待
    --sys.wait(60000000)
  end

  mqttc:close()
  mqttc = nil
end)
