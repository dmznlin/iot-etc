--[[-----------------------------------------------------------------------------
  作者： dmzn@163.com 2025-05-01
  描述： gps定位服务
-------------------------------------------------------------------------------]]
-- libgnss库初始化
libgnss.clear() -- 清空数据,兼初始化

local gnss = require("uc6228")

-- LED和ADC初始化
LED_GNSS = 24
gpio.setup(LED_GNSS, 0) -- GNSS定位成功灯

sys.taskInit(function ()
  gnss.setup({
    uart_id = 2,     -- GNSS芯片所接的UART ID, 默认是2
    debug = isDebug, -- 是否开启调试信息, 默认是false
    -- sys = 5,            -- 指定定位系统, 1:GPS, 2:BDS, 4:GLO, 默认是 3:GPS+BDS, 单北斗填2, 可选 1,2,3,5
    -- rmc_only = true,    -- 仅输出RMC信息,调试用
    -- nmea_ver = 41,      -- 设置NMEA协议版本,默认4.1
    -- no_nmea = true,     -- 关闭NMEA输出,调试用
  })

  pm.power(pm.GPS, true)
  gnss.start()
  gnss.agps()

  while true do
    if libgnss.isFix() then --已定位
      local loc = libgnss.getRmc(2) or {}
      Mqtt_send(string.format('{"cmd": 6, "lat": %s, "lng": %s}', loc.lat, loc.lng))
    end

    Mqtt_send("gps location")
    sys.wait(6000) --每分1次
  end
end)

-- 订阅GNSS状态编码
sys.subscribe("GNSS_STATE", function (event, ticks)
  -- event取值有
  -- FIXED 定位成功
  -- LOSE  定位丢失
  -- ticks是事件发生的时间,一般可以忽略
  local onoff = libgnss.isFix() and 1 or 0
  log.info("GNSS", "LED", onoff)
  gpio.set(LED_GNSS, onoff)
end)
