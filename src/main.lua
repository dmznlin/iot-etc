--[[-----------------------------------------------------------------------------
  作者： dmzn@163.com 2025-04-28
  描述： etc 4g 收费终端主程序
-------------------------------------------------------------------------------]]
PROJECT = "etc-4g-dev"
VERSION = "1.0.1"
-- luatools needs

_G.isDebug = true
--true: 调试模式开
log.setLevel("INFO")

_G.sys = require("sys")           --standard
_G.sysplus = require("sysplus")   --mqtt needs
_G.libfota2 = require("libfota2") --ota needs
require("sys_const")              -- global define

_G.device_id = mcu.unique_id():toHex()
log.info(string.format("启动中，系统:%s 内核:%s 标识:%s", VERSION, rtos.version(), device_id))

-- Air780E的AT固件默认会为开机键防抖, 导致部分用户刷机很麻烦
if rtos.bsp() == "EC618" and pm and pm.PWK_MODE then
  pm.power(pm.PWK_MODE, false)
end

sys.taskInit(function ()
  --看门狗：3秒一喂，9秒超时
  wdt.init(9000)
  sys.timerLoopStart(wdt.feed, 3000)
end)

---------------------------------------------------------------------------------
sys.taskInit(function ()
  -----------------------------
  -- 统一联网函数
  ----------------------------
  if wlan and wlan.connect then
    -- wifi
    local ssid = "ssid"
    local password = "pwd"
    log.info("wifi", ssid, password)

    -- TODO 改成自动配网
    -- LED = gpio.setup(12, 0, gpio.PULLUP)
    wlan.init()
    wlan.setMode(wlan.STATION) -- 默认也是这个模式,不调用也可以
    device_id = wlan.getMac()
    wlan.connect(ssid, password, 1)
  elseif mobile then
    -- Air780E/Air600E系列
    --mobile.simid(2) -- 自动切换SIM卡
    -- LED = gpio.setup(27, 0, gpio.PULLUP)
    device_id = mobile.imei()
  elseif w5500 then
    -- w5500 以太网, 当前仅Air105支持
    w5500.init(spi.HSPI_0, 24000000, pin.PC14, pin.PC01, pin.PC00)
    w5500.config() --默认是DHCP模式
    w5500.bind(socket.ETH0)
    -- LED = gpio.setup(62, 0, gpio.PULLUP)
  elseif socket or mqtt then
    -- 适配的socket库也OK
    -- 没有其他操作, 单纯给个注释说明
  else
    -- 其他不认识的bsp, 循环提示一下吧
    while 1 do
      sys.wait(1000)
      log.info("bsp", "本bsp可能未适配网络层, 请查证")
    end
  end

  log.info("联网中,请稍后...")
  sys.waitUntil(Status_IP_Ready)
  sys.publish(Status_Net_Ready, device_id)
end)

---------------------------------------------------------------------------------
local ota_opts = {}
local function ota_cb(ret)
  if ret == 0 then
    log.info("OTA: 下载成功,升级中...", true)
    rtos.reboot()
  elseif ret == 1 then
    Show_log("OTA: 连接失败,请检查url或服务器配置(是否为内网)", true)
  elseif ret == 2 then
    Show_log("OTA: url错误")
  elseif ret == 3 then
    Show_log("OTA: 服务器断开,检查服务器白名单配置", true)
  elseif ret == 4 then
    Show_log("OTA: 接收报文错误,检查模块固件或升级包内文件是否正常", true)
  elseif ret == 5 then
    Show_log("OTA: 版本号错误(xxx.yyy.zzz)", true)
  else
    Show_log("OTA: 未定义错误 " .. tostring(ret), true)
  end
end

-- 使用iot平台进行升级
sys.taskInit(function ()
  local first = true
  if isDebug then
    first = false --开发时关闭自动更新
  end

  while true do
    if not first then
      sys.waitUntil(Status_OTA_Update, 3600000 * 24) --每天1检
    end

    Show_log("OTA: 开始新版本确认")
    sys.wait(500)
    libfota2.request(ota_cb, ota_opts)
  end
end)

---------------------------------------------------------------------------------
-- 对于Cat.1模块, 移动/电信卡,通常会下发基站时间,那么sntp就不是必要的
-- 联通卡通常不会下发, 就需要sntp了
-- sntp内置了几个常用的ntp服务器, 也支持自选服务器

sys.taskInit(function ()
  if isDebug then --开发时不启用
    return
  end

  sys.waitUntil(Status_Net_Ready)
  sys.wait(1000)

  while true do
    -- 使用内置的ntp服务器地址, 包括阿里ntp
    log.info("NTP: 开始同步时间")
    socket.sntp()

    -- 通常只需要几百毫秒就能成功
    local ret = sys.waitUntil(Status_NTP_Ready, 5000)
    if ret then
      log.info("NTP: 时间同步成功 " .. os.date("%Y-%m-%d %H:%M:%S"))
      --每天一次
      sys.wait(3600000 * 24)
    else
      log.info("NTP: 时间同步失败")
      sys.wait(3600000) -- 1小时后重试
    end
  end
end)

---------------------------------------------------------------------------------
--加载业务: mqtt
require("sys_etc")

--加载业务: gps
require("sys_gps")

--代码结束
sys.run()
