--[[-----------------------------------------------------------------------------
  作者： dmzn@163.com 2025-04-28
  描述： 全局常量定义
-------------------------------------------------------------------------------]]
PRODUCT_KEY = "H1BQKAc5LXXa4crmQYbJnHpSYcH2EdiC"
-- 在线升级

Status_IP_Ready = "IP_READY"
--luat发送：网络就绪

Status_Net_Ready = "net_ready"
--系统消息：网络就位

Status_OTA_Update = "ota_update"
--系统消息：OTA在线升级

Status_Mqtt_ConnAck = "mqtt_conack"
--系统消息：mqtt连接成功

Mqtt_Topic_Pub = "etc/pub/%s"
--上报:设备 ---> 服务器
Mqtt_Topic_Sub = "etc/sub/%s"
--下发:设备 <--- 服务器
Mqtt_Topic_Srv = "etc/srv"
--广播：设备 <---> 服务器
Mqtt_Client_Online = "online" --[[{"cmd": "status", "val": "online"}]]
--系统：上线通知
Mqtt_Client_Will = "offline" --[[{"cmd": "status", "val": "offline"}]]
--系统：离线通知
