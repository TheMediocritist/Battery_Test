local gfx = playdate.graphics
import 'CoreLibs/graphics'
import 'CoreLibs/timer'
import 'CoreLibs/object'
gfx.setColor(gfx.kColorBlack)

local current_time = playdate.getTime()
local yyyymmddhhmm = current_time.year .. current_time.month .. current_time.day .. current_time.hour .. current_time.minute 

local fill_mid_alpha = gfx.image.new('images/fill_mid_alpha')
local font = gfx.font.new('fonts/Roobert-10-Bold')
gfx.setFont(font)

-- initialise the stuff
logfile = playdate.file.open("logfile_" ..yyyymmddhhmm .. ".csv", playdate.file.kFileWrite)
logfile:write("hour, minute, charging, simulator, bat_pc, bat_v, discharge_pc, discharge_v, ma_discharge_pc, ma_discharge_v\n")

stats_current = {}
stats_last = {}
stats_all = {}

function playdate.update()
    gfx.clear()
    current_time = playdate.getTime()
    if (current_time.second == 1 and current_time.minute ~= stats_last[2]) or #stats_current == 0 then
        sampleStats()
    end
    drawUI()
    drawStats()
end

function drawUI()
    gfx.setLineWidth(2)
    gfx.drawLine(20, 120, 20, 20)
    gfx.drawLine(20, 120, 180, 120)
    
    gfx.drawLine(220, 120, 220, 20)
    gfx.drawLine(220, 120, 380, 120)
    
    gfx.drawArc(100, 220, 60, -90, 90)
    gfx.drawArc(300, 220, 60, -90, 90)
    gfx.drawArc(100, 220, 5, -90, 90)
    gfx.drawArc(300, 220, 5, -90, 90)
    gfx.drawTextAligned("Percentage", 100, 5, kTextAlignment.center)
    gfx.drawTextAligned("Voltage", 300, 5, kTextAlignment.center)
    gfx.drawTextAligned("4.2", 206, 12, kTextAlignment.center)
    gfx.drawTextAligned("2.4", 206, 112, kTextAlignment.center)
    gfx.drawTextAligned("F", 10, 12, kTextAlignment.center)
    gfx.drawTextAligned("E", 10, 112, kTextAlignment.center)

end

function sampleStats()
    stats_current = {}
    local power_status = playdate.getPowerStatus()
    
    -- playdate.deviceWillSleep()
    -- Called before the device goes to low-power sleep mode because of a low battery.
    -- !! Probably should log this to the .csv
    
    local hour = current_time.hour
    local minute = current_time.minute
    local charging = power_status.USB and "USB" or power_status.charging and "charging" or "nope"
    local simulator = playdate.isSimulator and true or false
    local bat_pc = playdate.getBatteryPercentage()
    local bat_v = playdate.getBatteryVoltage()
    local discharge_pc = 0
    local discharge_v = 0
    local ma_discharge_pc = 0
    local ma_discharge_v = 0
    
    if #stats_last > 0 then
        discharge_pc = stats_last[5] - bat_pc
        discharge_ve = stats_last[6] - bat_v
        if #stats_all >= 2 then
            local counter = 0
            for record = #stats_all, 2, -1 do
                counter +=1
                ma_discharge_pc += stats_all[record][7]
                ma_discharge_v += stats_all[record][8]
            end
            ma_discharge_pc /= counter
            ma_discharge_v /= counter
        end
    end  
    
    stats_current = {hour, minute, charging, simulator, bat_pc, bat_v, discharge_pc, discharge_v, ma_discharge_pc, ma_discharge_v}
    
    -- send current stats to log file
    logStats(stats_current)
    
    -- copy stats_current to stats_last and stats_all then clear stats_current
    stats_last = stats_current
    table.insert(stats_all, stats_current)
end

function drawStats()
    -- draw % graph
    gfx.setLineWidth(1)
    local first = #stats_all
    local last = math.max(#stats_all - 80, 1)
    for record = first, last, -1 do
        local xpos = 22 + ((first - record) * 2)
        local ypos = 120
        local value = stats_all[record][5]
        gfx.drawLine(xpos, ypos, xpos, ypos- value)
    end
    
    -- draw voltage graph
    first = #stats_all
    last = math.max(#stats_all - 80, 1)
    for record = first, last, -1 do
        local xpos = 222 + ((first - record) * 2)
        local ypos = 120
        local value = 100 * (stats_all[record][6] - 2.4) / (4.2 - 2.4)
        gfx.drawLine(xpos, ypos, xpos, ypos- value)
    end
    
    -- draw % discharge 
    local min = 0
    local max = 1
    local current = 0
    if stats_current[9] == 0 then 
        current = stats_current[7]
    else 
        current = stats_current[9]
    end
    local current_norm = (current - min) / (max - min) 
    local current_norm_degrees = current_norm * 180
    gfx.setLineWidth(3)
    gfx.setPattern(fill_mid_alpha)
    gfx.fillEllipseInRect(44, 164, 112, 112, -90, -90 + current_norm_degrees)
    gfx.drawTextAligned(math.floor(current*100)/100 .. "% per minute", 100, 223, kTextAlignment.center)
    gfx.setColor(gfx.kColorBlack)
    local offset_x, offset_y = 0, 0
    if current_norm_degrees <= 90 then
        offset_x = -58 * math.cos(math.rad(current_norm_degrees))
        offset_y = -58 * math.sin(math.rad(current_norm_degrees))
    else
        offset_x = -58 * math.cos(math.rad(current_norm_degrees))
        offset_y = -58 * math.sin(math.rad(current_norm_degrees))
    end
    gfx.drawLine(100, 220, 100 + offset_x, 220 + offset_y)
    
    -- draw mV discharge 
    local min = 0
    local max = 10
    local current = 0
    if stats_current[10] == 0 then 
        current = stats_current[8]
    else 
        current = stats_current[10]
    end
    local current_norm = (current - min) / (max - min) 
    local current_norm_degrees = current_norm * 180
    gfx.setLineWidth(3)
    gfx.setPattern(fill_mid_alpha)
    gfx.fillEllipseInRect(244, 164, 112, 112, -90, -90 + current_norm_degrees)
    gfx.drawTextAligned(math.floor(current*100)/100 .. "mV per minute", 300, 223, kTextAlignment.center)
    gfx.setColor(gfx.kColorBlack)
    local offset_x, offset_y = 0, 0
    if current_norm_degrees <= 90 then
        offset_x = -58 * math.cos(math.rad(current_norm_degrees))
        offset_y = -58 * math.sin(math.rad(current_norm_degrees))
    else
        offset_x = -58 * math.cos(math.rad(current_norm_degrees))
        offset_y = -58 * math.sin(math.rad(current_norm_degrees))
    end
    gfx.drawLine(300, 220, 300 + offset_x, 220 + offset_y)
    
    gfx.drawTextAligned(stats_current[5] .. "%", 200, 140, kTextAlignment.center)
    gfx.drawTextAligned(stats_current[6] .. "V", 200, 160, kTextAlignment.center)
end

function logStats(stats)
    for item = 1, #stats do
        logfile:write(tostring(stats[item]) .. ",")
    end
    logfile:write("\n")
end
