--[[-----------------------------------------------------------------------------
  作者： dmzn@163.com 2025-04-28
  描述： 全局常量定义
-------------------------------------------------------------------------------]]
PRODUCT_KEY = "H1BQKAc5LXXa4crmQYbJnHpSYcH2EdiC"
-- 在线升级

Status_Log = "print_log"
--系统消息: 打印日志

Status_IP_Ready = "IP_READY"
--luat发送：网络就绪

Status_Net_Ready = "net_ready"
--系统消息：网络就位

Status_NTP_Ready = "NTP_UPDATE";
--系统消息: 时间同步完毕

Status_OTA_Update = "ota_update"
--系统消息：OTA在线升级

Status_Mqtt_Connected = "mqtt_conn"
--系统消息：mqtt连接成功

Status_Mqtt_SubData = "mqtt_sub"
--系统消息: mqtt收到订阅数据

Status_Mqtt_PubData = "mqtt_pub"
--系统消息: mqtt发布数据

Mqtt_Topic_Pub = "etc/pub/%s"
--上报:设备 ---> 服务器
Mqtt_Topic_Sub = "etc/sub/%s"
--下发:设备 <--- 服务器
Mqtt_Topic_Srv = "etc/srv"
--广播：设备 <---> 服务器

---------------------------------------------------------------------------------
--[[
  业务说明:
  1.设备每秒扫描一次,扫到 etc 后,得到 etc-id
  2.设备 -> 服务器发送 etc-id, 获取欠费单据列表
  3.服务器 -> 设备返回列表,开始循环(多单据)扣费
  4.设备 -> 服务器发送 单据号,申请该单据的扣费凭证
  5.服务器 -> 设备返回凭证
  6.设备 -> etc发送扣费凭证
  7.etc -> 设备返回预扣凭证(etc内部扣费业务流水号)
  8.设备 -> 服务器发送扣费请求
  9.服务器 -> 设备返回扣费状态(成功,失败)
  10.若成功, 设备 -> etc 发送预扣生效指令
  11.若失败, 设备 -> etc 发送预扣撤销指令
--]]

--上线
Cmd_Status_Online = 1
--{"cmd": 1, "id": "123"}

--离线
Cmd_Status_Offline = 2
--{"cmd": 2, "id": "123"}

--运行日志
Cmd_Run_log = 3
--srv: {"cmd": 3, "log": "open"}
--etc: {"cmd": 3, "log": "123"}

--获取系统信息
Cmd_Get_SysInfo = 4
--srv: {"cmd": 4}
--etc: {"cmd": 4, "sys":, "123"}

--立即开启OTA
Cmd_OTA_Start = 5
--{"cmd": 5}

--上报GPS
Cmd_GPS_Location = 6
--srv: {"cmd": 6, "loc":"open" }
--etc: {"cmd": 6, "lat": "1.1", "lng": "2.2"}

--串口通讯
Cmd_uart = 7
--srv: {"cmd": 7, "data":"55 AA" }
--etc: {"cmd": 7, "data":"55 AA" }

--使用 etc id 获取欠缴单据
Cmd_Get_Bills = 10
--etc: {"sn": "业务序号", "cmd": 10, "id": "123"}
--srv: {"sn": "业务序号", "cmd": 10, "err": "", "bills": "单据列表"}

--申请 扣费 凭证
Cmd_Get_PayToken = 20
--etc: {"sn": "业务序号", "cmd": 20, "id": "单据号"}
--etc: {"sn": "业务序号", "cmd": 20, "err": "", "id": "单据号", "token": "123"}

--执行 扣费
Cmd_PayBill = 21
--etc: {"sn": "业务序号", "cmd": 21, "id": "单据号", "token": "123", "etc": "456"}
--etc: {"sn": "业务序号", "cmd": 21, "err": "", "token": "123", "etc": "456"}

---------------------------------------------------------------------------------
local id_base = 0  --序列基准
local id_date = "" --时间基准

--[[
  描述: 生成业务流水号
  格式:
    1.6位设备ID: device_id 后6位
    2.6位日期: 2位年 月 日
    3.6位时间: 时 分 秒
    4.序列号
--]]
function Make_ID()
  local str = os.date("%y%m%d%H%M%S")
  if str ~= id_date then --时间变更,重置序列
    if id_base >= 9 then
      id_base = 0
    end

    id_date = tostring(str)
  end

  id_base = id_base + 1
  return string.sub(device_id, #device_id - 5) .. str .. tostring(id_base)
end

---系统信息
function Sys_Info()
  local info = {}
  info["sys.name"] = PROJECT
  info["sys.ver"] = VERSION
  info["sys.core"] = rtos.version()

  info["id.cpu"] = mcu.unique_id():toHex()
  info["id.dev"] = device_id

  info["mem.sys"] = string.format("%d,%d,%d", rtos.meminfo("sys")) -- 系统内存
  info["mem.lua"] = string.format("%d,%d,%d", rtos.meminfo("lua")) -- 虚拟机内存

  if libgnss.isFix() then                                          --已定位
    local loc = libgnss.getRmc(2) or {}
    info["gps.lat"] = loc.lat                                      --纬度, 正数为北纬, 负数为南纬
    info["gps.lng"] = loc.lng                                      --经度, 正数为东经, 负数为西经

    local gsa = libgnss.getGsa()
    info["gps.gsa"] = gsa.sats --正在使用的卫星编号
  end

  return info
end

--[[
  date: 2025-05-01
  parm: precision 浮点精度,默认2
  desc: table转字符串
--]]
function Table_to_string(tbl, precision)
  local to_str = function (value)
    if type(value) == 'table' then
      return Table_to_string(value)
    elseif type(value) == 'string' then
      return "\'" .. value .. "\'"
    else
      return tostring(value)
    end
  end

  if tbl == nil then return "" end
  local ret = "{"

  local idx = 1
  for key, value in pairs(tbl) do
    local signal = ","
    if idx == 1 then
      signal = ""
    end

    if key == idx then
      ret = ret .. signal .. to_str(value)
    else
      if type(key) == 'number' or type(key) == 'string' then
        ret = ret .. signal .. '[' .. to_str(key) .. "]=" .. to_str(value)
      else
        if type(key) == 'userdata' then
          ret = ret .. signal .. "*s" .. Table_to_string(getmetatable(key)) .. "*e" .. "=" .. to_str(value)
        else
          ret = ret .. signal .. key .. "=" .. to_str(value)
        end
      end
    end

    idx = idx + 1
  end

  ret = ret .. "}"
  return ret
end

--[[
  date: 2025-05-01
  parm: value 字符串
  desc: 字符串转table
--]]
function Table_from_str(value)
  if not value or value == "" then
    return nil, "table string empty"
  end

  -- 使用 load 安全地解析字符串
  local chunk, err = load("return " .. value)
  if not chunk then
    return nil, "table string invalid: " .. (err or "unknown error")
  end

  -- 执行并返回解析后的 table
  local success, result = pcall(chunk)
  if not success then
    return nil, "convert string failed: " .. result
  end

  return result or {}
end

--[[
  date: 2025-05-04
  parm: 字符串
  desc: 将str转为16进制表示
--]]
function Str_to_hex(str)
  local first = true
  return string.gsub(str, "(.)", function (x)
    local ret = string.format(first and "%02X" or " %02X", string.byte(x))
    if first then first = false end
    return ret
  end)
end

--[[
  date: 2025-05-04
  parm: 16进制字符串(55 AA)
  desc: 将hex转为字符串
--]]
function Str_from_hex(hex)
  local str = hex:gsub("[%s%p]", ""):upper()
  return str:gsub("%x%x", function (c)
    return string.char(tonumber(c, 16))
  end)
end
