local VERSION = '0.996'

local DEVICETYPE_RELAY = "urn:schemas-upnp-org:device:BinaryLight:1"
local DEVICEFILE_RELAY = "D_BinaryLight1.xml"

local SWP_SID = "urn:upnp-org:serviceId:SwitchPower1"
local SWP_STATUS = "Status"
local SWP_TARGET = "Target"
local SWP_SET_TARGET = "SetTarget"

local DEVICETYPE_MOTION_SENSOR = "urn:schemas-micasaverde-com:device:MotionSensor:1"
local DEVICEFILE_MOTION_SENSOR = "D_MotionSensor1.xml"

local SES_SID = "urn:micasaverde-com:serviceId:SecuritySensor1"
local SES_ARMED = "Armed"
local SES_TRIPPED = "Tripped"
local SES_LAST_TRIP = "LastTrip"

local DEVICETYPE_COUNTER = "urn:schemas-zoot-com:device:Counter:1"
local DEVICEFILE_COUNTER = "D_Counter1.xml"
local COUNTER_SID = "urn:zoot-org:serviceId:Counter1"
local COUNTER_CURRENT = "CurrentCount"

local DEVICETYPE_RAIN8NET = "urn:schemas-wgldesigns-com:device:Rain8Net:1"
local DEVICEFILE_RAIN8NET = "D_Rain8net1.xml"

local R8N_SID = "urn:wgldesigns-com:serviceId:Rain8Net1"
local R8N_MOD = "ModId"
local R8N_MAX = "MaxValveOpen"
local COUNT_CURRENT = "CurrentCounter"
local RESET_COUNTER = "ResetCounter"
local R8N_SET_TARGET = "SetTarget"

local HADEVICE_SID = "urn:micasaverde-com:serviceId:HaDevice1"
local HAD_POLL = "Poll"
local HAD_SET_POLL_FREQUENCY = "SetPollFrequency"
local HAD_LAST_UPDATE = "LastUpdate"
local HAD_COMM_FAILURE = "CommFailure"
local HAD_CONFIGURED = "Configured"

local QUEUE_MAX = 40
local WAIT_MAX = 5
local R8NMODULE

local MODID = 1
local OPEN = 0
local VALVEMAX = 3

local r8nComCheck = 0x70
local r8nStatus = 0xF0
local r8nHeader = 0x40
local r8nOn  = 0x30
local r8nOff = 0x40
local r8nAllOffHeader = 0x20
local r8nAllOff = 0x55
local r8nInput = 0x50
local r8nSensor = 0xEF
local r8nCounter = 0xE0
local r8nResetCounter = 0xE7

local intervalCount = 0
local buffer = ""
local DEBUG_MODE = false
local TASK_ERROR      = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS    = 4
local TASK_BUSY       = 1
local g_taskHandle = -1

local programTable={}
local zoneStatusTable={}
--------------------------------------------------------------------------------
-- General functions
--------------------------------------------------------------------------------
local function log(text, level)
  luup.log("Rain8Net: " .. text, (level or 50))
end



local function debug(text)
  if (DEBUG_MODE == true) then
    log("debug: " .. text, 1)
  end
end



function task (text, mode)
  log("task: ".. text)
  if (mode == TASK_ERROR_PERM) then
    luup.task(text, TASK_ERROR, "Rain8Net", g_taskHandle)
  else
    luup.task(text, mode, "Rain8Net", g_taskHandle)
    -- Clear the previous error, since they're all transient
    if (mode ~= TASK_SUCCESS) then
      luup.call_delay("clearStatusMessage", 30, "", false)
    end
  end
end



function clearStatusMessage()
  debug("Clearing status message")
  luup.task("Clear", TASK_SUCCESS, "Rain8Net", g_taskHandle)
  return true
end



local function findChild(ParentDevice, label)
  for k, v in pairs(luup.devices) do
    if (tostring(v.device_num_parent) == tostring(ParentDevice) and tostring(v.id) == label) then
      return k
    end
  end
  return false
end



local function addrZone(zone)
  local addr = (tonumber(string.sub(zone,1,2),16)) or false
  zone =  (tonumber(string.sub(zone,3,4),16)) or false
  return addr, zone
end



local function hex2Bin(s)
  local Hex2BinTable = {
  ["0"] = "0000",
  ["1"] = "0001",
  ["2"] = "0010",
  ["3"] = "0011",
  ["4"] = "0100",
  ["5"] = "0101",
  ["6"] = "0110",
  ["7"] = "0111",
  ["8"] = "1000",
  ["9"] = "1001",
  ["a"] = "1010",
  ["b"] = "1011",
  ["c"] = "1100",
  ["d"] = "1101",
  ["e"] = "1110",
  ["f"] = "1111"
  }
  local binary = ""
  local i = 0
  for i in string.gfind(s, ".") do
    i = string.lower(i)
    binary = binary .. Hex2BinTable[i]
  end
   return binary
end



local function sleep(ms)
    luup.sleep(ms)
end
--------------------------------------------------------------------------------
-- Test functions
--------------------------------------------------------------------------------


function r8nCommunicationCheck(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nCommunicationCheck"
  local errorMessage = "Communications check failed."
  if (byte1 == r8nComCheck) then
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function r8nModuleFind(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nModuleFind"
  local errorMessage = "Failed to find module at address " .. byte2 .. "."
  if (byte1 == r8nHeader) then
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function r8nSensorFind(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nSensorFind"
  local errorMessage = "Failed to find sensor at address " .. byte2 .. "."
  if (byte1 == r8nInput) then
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function r8nCounterFind(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nCounterFind"
  local errorMessage = "Failed to find counter at address " .. byte2 .. "."
  if (byte1 == r8nInput) then
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function r8nModuleOff(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nModuleOff"
  local errorMessage = "Failed to switch zones off at address " .. byte2 .. "."
  if (byte1 == r8nHeader) then
    luup.variable_set(SWP_SID,SWP_STATUS,"0",device)
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function r8nGlobalOff()
  local functionName = "r8nGlobalOff"
  local errorMessage = "Failed to switch global zones off at address."
  if (luup.io.write(string.char(0x20,0x55,0x55))) then
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function r8nZoneControl(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nZoneControl"
  local errorMessage = string.format("Failed to change zone status of zone 0x%02X at address 0x%02X.",byte3,byte2)
  if (byte1 == r8nHeader) then
    luup.variable_set(SWP_SID,SWP_STATUS,newTargetValue,device)
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function   r8nCounterStatus(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nCounterStatus"
  local errorMessage = "Failed to get counter status at address " .. byte2 .. "."
  if (byte1 == r8nInput) then
    debug(string.format("r8nCounterStatus: counterUpperByte=0x%02X counterLowerByte=0x%02X device=%i",byte2,byte3,device))
    local time = os.time()
    local LastUpdate = luup.variable_get(HADEVICE_SID, HAD_LAST_UPDATE, device)
    local counter = ((byte2 * 256)+byte3)
    local countPrev = (tonumber(luup.variable_get(COUNTER_SID, COUNTER_CURRENT, device),10) or 0)
    R_SEC = (counter < countPrev) and (counter -(65535 - countPrev)) or (counter - countPrev)
    luup.variable_set (HADEVICE_SID, HAD_LAST_UPDATE, time, device)
    luup.variable_set (COUNTER_SID, COUNTER_CURRENT, counter, device)
    luup.variable_set (COUNTER_SID,"R Sec", R_SEC, device)
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function r8nCounterReset(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nCounterReset"
  local errorMessage = "Failed to reset counter at address " .. byte2 .. "."
  if (byte1 == r8nInput) then
    debug(string.format("r8nCounterReset: reset command=0x%02X device=%i",byte3,device))
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function   r8nSensorStatus(byte1,byte2,byte3,device,newTargetValue)
  local functionName = "r8nSensorStatus"
  local errorMessage = "Failed to get sensor at address " .. byte2 .. "."
  if (byte1 == r8nInput) then
    local t = os.time()
    debug(string.format("r8nSensorStatus: Sensor=0x%02X Status=0x%02X device=%i",byte2,byte3,device))
    luup.variable_set(SES_SID,"Actual",string.format("0x%02X",byte3),device)
    luup.variable_set(HADEVICE_SID, HAD_LAST_UPDATE, t, device)
    local currentState = luup.variable_get(SES_SID, SES_TRIPPED, device)
    local status = (byte3 == 0x64) and "1" or "0"
    if((tonumber(currentState) == 0 and tonumber(status)) ~= (tonumber(currentState) or 0)) then
      luup.variable_set (SES_SID, SES_LAST_TRIP, t, device)
    end
    luup.variable_set(SES_SID, SES_TRIPPED, status, device)
    return true
  else
    debug(functionName .. ": " .. errorMessage)
    return false
  end
end



function requestTimers(device)
  local functionName = "RequestTimers"
  local errorMessage = "Failed to get timers for device " .. device .. "."
  debug(functionName .. ": STUB" .. errorMessage)
end



function setTimers(device, Timers)
  local functionName = "SetTimers"
  --local interval = string.match (program, "^(%d+)([MmHh]?)")

  local zone = tonumber(Timers.Zone)
  luup.variable_set(SWP_SID,"Program_A",Timers.ProgramA, zone)
  luup.variable_set(SWP_SID,"Program_B",Timers.ProgramB, zone)
  local errorMessage = "Failed to set timers for device " .. device .. "."
  debug(functionName .. ": STUB:" .. errorMessage .. " Timers:" .. Timers.ProgramA .. ":" ..  Timers.ProgramB .. ".")
end

--------------------------------------------------------------------------------
-- Status
--------------------------------------------------------------------------------
function r8nZoneStatus(byte1,byte2,byte3,device,newTargetValue)
  if (byte1 == r8nHeader) then
    zoneStatusTable={}
    OPEN = 0
    debug(string.format("r8nZoneStatus: address=0x%02X status=0x%02X device=%i",byte2,byte3,device))
    local state = hex2Bin(string.format("%02X",byte3))
    luup.variable_set(R8N_SID,"State",state,device)
    byte3 = (byte3 > 0) and "1" or "0"
    luup.variable_set(R8N_SID,SWP_STATUS,byte3,device)
    for i = 1,8 do
      local zone = string.format("%02X", i)
      local status = (string.reverse(state)):sub(i,i)
      local device = findChild(R8NMODULE,string.format("%02X",byte2)..zone)
      luup.variable_set(SWP_SID,SWP_STATUS,status,device)
      luup.variable_set (HADEVICE_SID, HAD_LAST_UPDATE, os.time(), device)
    end
    for k, v in pairs(luup.devices) do
      if (tostring(R8NMODULE) == tostring(v.device_num_parent) and tostring(v.device_type)==DEVICETYPE_RELAY) then
        local pump = luup.variable_get(SWP_SID,"PumpNumber",k)
        local status = tonumber(luup.variable_get(SWP_SID,SWP_STATUS,k),10)
        OPEN = OPEN + (status or 0)
        local zonePerPump = tonumber(zoneStatusTable[pump] or 0) + (status or 0)
        zoneStatusTable[pump] = zonePerPump
      end
    end
    for k, v in pairs(zoneStatusTable) do
      local zoneString = (v == 1) and "zone" or "zones"
      local open = (v == 0) and "no" or tostring(v)
      if(k == "0") then
        debug(string.format("r8nZoneStatus: %04s %s open with no pump.",open,zoneString))
      else
        debug(string.format("r8nZoneStatus: %04s %s open for pump %s.",open,zoneString,k))
      end
    end
    debug(string.format("r8nZoneStatus: %i zones open.",OPEN))
    local parentState = (OPEN > 0) and "1" or "0"
    luup.variable_set(R8N_SID,SWP_STATUS,parentState,R8NMODULE)
    return true
  else
    return false
  end
end
--------------------------------------------------------------------------------
-- Incoming data handler
--------------------------------------------------------------------------------
function incomingData(lul_data)
  --Incoming data handler.
  local data = tostring(lul_data)
  debug(string.format("incomingData: data=0x%02X", data:byte(1)))
end
--------------------------------------------------------------------------------
-- Polling
--------------------------------------------------------------------------------
function pollTimed()
  local pollInterval = luup.variable_get(HADEVICE_SID,HAD_POLL,R8NMODULE)
	luup.call_timer("pollTimed", 1, pollInterval, "", "")
	pollModule()
end


function pollModule()
  for k, v in pairs(luup.devices) do
    if (tostring(R8NMODULE) == tostring(v.device_num_parent)) then
      local addr, zone = addrZone(v.id)
      if (tostring(v.device_type) == DEVICETYPE_MOTION_SENSOR) then
        log(string.format("pollModule: updating status of sensor on device number %i",k))
        r8nSendIntercept(string.char(r8nInput,addr,r8nSensor),r8nSensorStatus,k)
      elseif (tostring(v.device_type) == DEVICETYPE_COUNTER) then
        log(string.format("pollModule: updating status of counter on device number %i",k))
        r8nSendIntercept(string.char(r8nInput,addr,r8nCounter),r8nCounterStatus,k)
      elseif (tostring(v.device_type) == DEVICETYPE_RAIN8NET) then
        log(string.format("pollModule: updating status of zones on device number %i",k))
        r8nSendIntercept(string.char(r8nHeader,addr,r8nStatus),r8nZoneStatus,k)
      else
        debug(string.format("pollModule: unhandled device type %s on device number %i",v.device_type,k))
      end
    end
  end
  return true
end

function pollCounter()
  for k, v in pairs(luup.devices) do
    if (tostring(R8NMODULE) == tostring(v.device_num_parent)) then
      local addr, zone = addrZone(v.id)
      if (tostring(v.device_type) == DEVICETYPE_COUNTER) then
        log(string.format("pollCounter: updating status of counter on device number %i",k))
        r8nSendIntercept(string.char(r8nInput,addr,r8nCounter),r8nCounterStatus,k)
      else
        debug(string.format("pollCounter: unhandled device type %s on device number %i",v.device_type,k))
      end
    end
  end
  return true
end

function poll()
  for k, v in pairs(luup.devices) do
    if (tostring(R8NMODULE) == tostring(v.device_num_parent) and tostring(v.device_type) == DEVICETYPE_RAIN8NET) then
      local addr, zone = addrZone(v.id)
      debug(string.format("poll: updating status of zones (device=%i)",k))
      r8nSendIntercept(string.char(r8nHeader,addr,r8nStatus),r8nZoneStatus,k)
    end
  end
  return true
end
--------------------------------------------------------------------------------
-- Programs
--------------------------------------------------------------------------------
function runCycle(devid)
  local previousDevice = tonumber(devid)
  if(#programTable == 0) then
    log("runCycle: Cycle complete")
    luup.variable_set(R8N_SID,"program","OK",R8NMODULE)
    luup.call_timer("stopCycle", 1, 10, "", previousDevice)
    luup.call_action(R8N_SID,R8N_SET_TARGET,{ newTargetValue="0" },R8NMODULE)
  end
  local data = programTable[1]
  local nextZone = data[1]
  local device = data[2]
  local timer = data[3]
  local pump = data[4]
  local pumpPrev = data[5]
  table.remove(programTable,1)
  log(string.format("runCycle: start, (device=%i) (zone=%s) (timer=%s) (pump=%s): ",device, nextZone, timer, (pump or "none")))
  if(#programTable ~= 0) then
    programTable[1][5]=pump
  end
  if (pump ~= pumpPrev and previousDevice~=nil) then
    debug(string.format("runCycle: check pumps and prev device, (device=%i) (pump=%s) (prevPump=%s): ",previousDevice,(pump or "none"),(pumpPrev or "none")))
    luup.call_action(SWP_SID,SWP_SET_TARGET,{ newTargetValue="0" },previousDevice)
    previousDevice=nil
  end
  luup.call_action(SWP_SID,SWP_SET_TARGET,{ newTargetValue="1" },device)
  if (previousDevice~=nil) then
    debug(string.format("runCycle: check pumps and prev device_, (device=%i) (pump=%s) (prevPump=%s): ",previousDevice,(pump or "none"),(pumpPrev or "none")))
    luup.call_timer("stopCycle", 1, 30, "", previousDevice)
  end
  luup.call_timer("runCycle", 1, timer, "", device)
  return true
end



function stopCycle(previousDevice)
  previousDevice = tonumber(previousDevice)
  debug(string.format("stopCycle: shutdown, (previous device=%i): ",previousDevice))
  luup.call_action(SWP_SID,SWP_SET_TARGET,{ newTargetValue="0" },previousDevice)
  return true
end


function callbackHandler(lul_request, lul_parameters, lul_outputformat)
  local functionName = "callbackHandler"
  if (lul_request == "programs" and lul_outputformat == "json") then
    return "[" .. table.concat(listCycles(),",") .. "]"
  else
    debug("callbackHandler:" .. tostring(lul_outputformat) .. " currently not supported.")
    return tostring(lul_outputformat) .." currently not supported."
  end
end



function listCycles()
  local programs = {}
  local timers = {}
  for k, v in pairs(luup.devices) do
   if (tostring(R8NMODULE) == tostring(v.device_num_parent) and tostring(v.device_type)==DEVICETYPE_RELAY) then
    local programA = luup.variable_get(SWP_SID,"Program_A",k) or "0"
    local programB = luup.variable_get(SWP_SID,"Program_B",k) or "0"
    local pump = luup.variable_get(SWP_SID,"PumpNumber",k) or "0"
    local lastRun = luup.variable_get(SWP_SID,"LastRun",k) or "0"
    local relay = tostring(v.id)
    debug(string.format("listCycles:Relay=%s: Device=%i: Pump=%s: ProgA=%s: ProgB=%s: Last Run=%s: ",relay, k, pump, programA, programB, lastRun))
    table.insert(programs,{relay, k, pump, programA, programB, lastRun})
   end
  end
  table.sort (programs, function (v1, v2)  return v1[3].. v1[1] < v2[3].. v2[1] end)
  
  for k, v in ipairs(programs) do
    table.insert(timers,"{" ..
      "\"Zone\": \"" .. v[1] .. "\"," ..
      "\"Device\": \"" .. v[2] .. "\"," ..
      "\"Master\": \"" .. v[3] .. "\"," ..
      "\"ProgramA\": \"" .. v[4] .. "\"," ..
      "\"ProgramB\": \"" .. v[5] .. "\"," ..
      "\"LastRun\": \"" .. v[6] .. "\"" ..
      "}")
  end
  return timers
end


function cycle(lul_device, programNumber)
  luup.variable_set(R8N_SID,"program",programNumber,R8NMODULE)
  if(programNumber == "cancel") then
    programTable = {}
    luup.call_action(R8N_SID,R8N_SET_TARGET,{ newTargetValue="0" },R8NMODULE)
    luup.variable_set(R8N_SID,"program","OK",R8NMODULE)
    return true
  end
  for k, v in pairs(luup.devices) do
   local program = luup.variable_get(SWP_SID,"Program_"..programNumber,k)
   if (tostring(R8NMODULE) == tostring(v.device_num_parent) and tostring(v.device_type)==DEVICETYPE_RELAY and program ~= "0") then
    local pump = luup.variable_get(SWP_SID,"PumpNumber",k)
    local timer, interval = string.match (program, "^(%d+)([MmHh]?)")
    local relay = tostring(v.id)
    timer = timer..(interval or "")
    debug(string.format("cycle: valve added to autocycle, (relay=%s) (device=%i) (timer=%s) (pump=%s): ",relay,k,timer,pump))
    table.insert(programTable,{relay, k, timer, pump})
   end
  end
  --sort order master then zone.
  table.sort (programTable, function (v1, v2)  return v1[4].. v1[1] < v2[4].. v2[1] end)
  debug(string.format("cycle: number of  zones=%i",#programTable))
  if(#programTable > 0) then
    task(string.format("program %s running.", programNumber), TASK_BUSY)
    runCycle()
  end
  return true 
end
--------------------------------------------------------------------------------
-- Message processing
--------------------------------------------------------------------------------
function processMessage(func, device, newTargetValue)
  local packet = ""
  while true do
    data = luup.io.read()
    luup.io.intercept()
    if (data ~= nil) then
      packet = packet..data
      if (string.len(packet) == 3) then
        status = string.format("%02X:%02X:%02X",packet:byte(1), packet:byte(2), packet:byte(3))
        debug("processMessage: " .. status)
        luup.variable_set(R8N_SID,"State",status,R8NMODULE)
        return func(packet:byte(1),packet:byte(2),packet:byte(3),device,newTargetValue)
      end
    else
      return false
    end
  end
end



function r8nSendIntercept(r8ncommand, func, device, newTargetValue)

    sleep(300) --gap between sending commands
    luup.io.intercept()
    if (not luup.io.write(r8ncommand)) then
      log("((::sendCommand) ERROR: Failed to send command: '".. (cmd or "") .."'.")
      return false
    end
    return processMessage(func, device, newTargetValue)
end
--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------
function r8nModuleSetTarget(lul_device)
  local altid = (tostring(luup.devices[lul_device].id))
  local addr, zone = addrZone(altid)
  if(addr == false) then
    r8nGlobalOff()
  else
    log(string.format ("r8nModuleSetTarget: all zones off address=0x%02X", addr))
    r8nSendIntercept((string.char(r8nHeader,addr,r8nAllOff)),r8nModuleOff,lul_device)
  end
  poll()
  return true
end



function sensorArm(lul_device, newTargetValue)
  luup.variable_set(SES_SID,SES_ARMED,newTargetValue,lul_device)
end



function resetCounter(lul_device)
	local altid = (tostring(luup.devices[lul_device].id))
	local addr, zone = addrZone(altid)
	debug(string.format ("resetCounter: counter on module 0x%02X on", addr))
  r8nSendIntercept((string.char(r8nInput,addr,r8nResetCounter)),r8nCounterReset,lul_device)
  return pollCounter()
end



function r8nSetTarget(lul_device, newTargetValue)
  local pump = tostring(luup.variable_get(SWP_SID, "PumpNumber", lul_device))
  local pumpDev = findChild(R8NMODULE, pump)
  local altid = (tostring(luup.devices[lul_device].id))
  local addr, zone = addrZone(altid)
  local pumpAddr, pumpZone = addrZone(pump)
  local time = os.time()
  local startTime = tonumber(luup.variable_get(SWP_SID,"LastRun",lul_device),10)
  local pumpList = zoneStatusTable[pump] or 0
  if(newTargetValue=="1") then
    r8nSendIntercept((string.char(r8nHeader,addr,(r8nOn+zone))),r8nZoneControl,lul_device,newTargetValue)
    luup.variable_set(SWP_SID,"LastRun",time,lul_device)
    debug(string.format ("r8nSetTarget: zone 0x%02X on module 0x%02X on", zone, addr))
    if(pumpDev ~= false) then
      r8nSendIntercept((string.char(r8nHeader,pumpAddr,(pumpZone + r8nOn))),r8nZoneControl,pumpDev,newTargetValue)
      luup.variable_set(SWP_SID,"LastRun",time,pumpDev)
      debug(string.format ("r8nSetTarget: pump 0x%02X on module 0x%02X on", pumpZone, pumpAddr))
    end
  else
    local runTime = os.difftime(time, startTime) or time
    if(pumpList <= 1 and pumpDev ~= false) then
      r8nSendIntercept((string.char(r8nHeader,pumpAddr,(pumpZone + r8nOff))),r8nZoneControl,pumpDev,newTargetValue)
      log(string.format ("r8nSetTarget: address=0x%02X, zone=0x%02X runtime=%s", addr, zone, runTime))
      luup.variable_set(SWP_SID,"LastRun",time,pumpDev)
      luup.variable_set(SWP_SID,"lastRunTime",math.ceil(runTime/60),pumpDev)
      debug(string.format ("r8nSetTarget: pump 0x%02X on module 0x%02X on", pumpZone, pumpAddr))
    end
    debug(string.format ("r8nSetTarget: zone 0x%02X on module 0x%02X off", zone, addr))
    r8nSendIntercept((string.char(r8nHeader,addr,(r8nOff+zone))),r8nZoneControl,lul_device,newTargetValue)
    log(string.format ("r8nSetTarget: address=0x%02X, zone=0x%02X runtime=%s", addr, zone, runTime))
    luup.variable_set(SWP_SID,"LastRun", time, lul_device)
    luup.variable_set(SWP_SID,"lastRunTime",math.ceil(runTime/60), lul_device)
  end
  return poll()
end
--------------------------------------------------------------------------------
-- Initialisation
--------------------------------------------------------------------------------
local function initParameter()
  time = os.time()
  for k, v in pairs(luup.devices) do
    if tostring(v.device_num_parent) == tostring(R8NMODULE)  then
      if tostring(v.device_type) == DEVICETYPE_RELAY  then
        luup.variable_set(HADEVICE_SID, HAD_LAST_UPDATE, time, k)
        local pumpNumber = (luup.variable_get(SWP_SID,"PumpNumber",k) or "")
        if (pumpNumber == "") then
          luup.variable_set(SWP_SID,"PumpNumber",'0',k)
        end
        local lastRun = (luup.variable_get(SWP_SID,"LastRun",k) or "")
        if (lastRun == "") then
          luup.variable_set(SWP_SID,"LastRun","0",k)
        end
        local lastRunTime = (luup.variable_get(SWP_SID,"lastRunTime",k) or "")
        if (lastRunTime == "") then
          luup.variable_set(SWP_SID,"lastRunTime","0",k)
        end
        local program_A = (luup.variable_get(SWP_SID,"Program_A",k) or "")
        if (program_A == "") then
          luup.variable_set(SWP_SID,"Program_A","0",k)
        end
        local program_B = (luup.variable_get(SWP_SID,"Program_B",k) or "")
        if (program_B == "") then
          luup.variable_set(SWP_SID,"Program_B","0",k)
        end
      elseif tostring(v.device_type) == DEVICETYPE_MOTION_SENSOR  then
        local arm = (luup.variable_get(SES_SID,SES_ARMED,k) or "")
        if (arm == "") then
          luup.variable_set(SES_SID,SES_ARMED,'1',k)
        end
      elseif tostring(v.device_type) == DEVICETYPE_COUNTER  then
        local rev = (luup.variable_get(COUNTER_SID,"R Sec",k) or "")
        if (rev == "") then
          luup.variable_set(COUNTER_SID,"R Sec",'0',k)
        end
      else
        debug(string.format("initParameter: \"%s\" device type with device number %i under parent device %i not handled", v.device_type, k, R8NMODULE))
      end
    end
  end
end



local function moduleCreate(module, childDevice)

  log("moduleCreate: module number:" .. module)
  local address = tonumber(module)
  local moduleAddress = string.format("%02X",address)
  if (r8nSendIntercept(string.char(r8nHeader,address,r8nStatus),r8nModuleFind) == true) then
      
    luup.chdev.append(R8NMODULE,childDevice,moduleAddress .."55", string.format("Module %02X",address),
    DEVICETYPE_RAIN8NET,DEVICEFILE_RAIN8NET,"","",false)
    log(string.format("moduleCreate: module %02X:", address))
    --create module zone child devices
    for i = 1,8 do
      local zone = moduleAddress .. string.format("%02X", i)
      luup.chdev.append(R8NMODULE,childDevice,zone,string.format("Module %02X:Zone %X",address, i),
      DEVICETYPE_RELAY,DEVICEFILE_RELAY,"","",false)
      debug(string.format("moduleCreate: module %02X:Zone %X:", address,i))
    end
    --create module input child devices
    if(r8nSendIntercept(string.char(r8nInput,address,r8nSensor),r8nSensorFind) == true) then
      local switch = string.format("%02X", address) .. string.format("%02X", r8nSensor)
      luup.chdev.append(R8NMODULE,childDevice,switch,string.format("Module %02X:Sensor",address),
      DEVICETYPE_MOTION_SENSOR,DEVICEFILE_MOTION_SENSOR,"","",false)
      log(string.format("moduleCreate: module %02X:Switch", address))
    elseif(r8nSendIntercept(string.char(r8nInput,address,r8nCounter),r8nCounterFind) == true) then
      local counter = string.format("%02X", address) .. string.format("%02X", r8nCounter)
      luup.chdev.append(R8NMODULE,childDevice,counter,string.format("Module %02X:Counter",address),
      DEVICETYPE_COUNTER,DEVICEFILE_COUNTER,"","",false)
      log(string.format("moduleCreate: module %02X:Counter", address))
    else
      debug(string.format("moduleCreate: no input devices found %02X", address))
    end
    
    return true
  else
    return false
  end
    
end



local function getModules()
    
  local modId = luup.variable_get(R8N_SID,R8N_MOD,R8NMODULE) or ""
  if(modId == "") then
    luup.variable_set(R8N_SID,R8N_MOD,MODID,R8NMODULE)
  end
  
  local module_config = true
  childDevice = luup.chdev.start(R8NMODULE)
    
  for module, sep, other in string.gfind(modId, "(%d+)(-*)(%d*)") do
    local module_avail
    if sep == "-" then
      for module = module,other do
        module_avail = moduleCreate(module, childDevice)
        module_config = (module_config == false) and false or module_avail
      end
    else
      module_avail = moduleCreate(module, childDevice)
      module_config = (module_config == false) and false or module_avail
    end
  end
  
  if(module_config == true) then
    luup.variable_set(HADEVICE_SID, HAD_CONFIGURED, "1", R8NMODULE)
    debug("getModules:Not all modules from list configured")
  else
    debug("getModules:Not all modules from list configured")
    debug("getModules:Please check connections or check list is correct")
  end
  
  luup.chdev.sync(R8NMODULE,childDevice)
end



local function r8nConnect(lul_device)
  local ipAddress, ipPort = string.match (luup.devices[lul_device].ip, "^(.*):(%d+)")
  if (ipAddress and ipAddress ~= "") then
    if (not ipPort) then
      ipPort = 4001
    end
    log(string.format ("r8nStartup: ipAddress=%s, ipPort=%s", tostring (ipAddress),
    tostring (ipPort)))
    luup.io.open (lul_device, ipAddress, ipPort)
  else
    log ("Rain8Net: running on Serial.")
  end
end



function taskHandleCreate()
  g_taskHandle = luup.task("startup successful", TASK_SUCCESS, "Rain8Net", g_taskHandle)
end



function r8nStartup(lul_device)
  R8NMODULE = lul_device
  r8nConnect(R8NMODULE)
  
  local debugMode = luup.variable_get(R8N_SID, "DebugMode", R8NMODULE) or ""
  if (debugMode ~= "") then
    DEBUG_MODE = (debugMode == "1") and true or false
  else
    luup.variable_set(R8N_SID, "DebugMode", (DEBUG_MODE and "1" or "0"), R8NMODULE)
  end
  
  log("getDebugMode: Debug mode "..(DEBUG_MODE and "enabled" or "disabled")..".")
  if (r8nSendIntercept(string.char(r8nComCheck,0x00,0x00),r8nCommunicationCheck) == true) then
    log(string.format("r8nStartup: Rain8Net module available, (device=%i): ",R8NMODULE))
    luup.variable_set(R8N_SID,"State","Ready",R8NMODULE)
    luup.variable_set(HADEVICE_SID,HAD_COMM_FAILURE,"0",R8NMODULE)
  else
    log(string.format("r8nStartup: Rain8Net not currently available, plugin exiting (device=%i)",R8NMODULE))
    luup.variable_set(HADEVICE_SID,HAD_COMM_FAILURE,"1",R8NMODULE)
    return false, "Device not available", "Rain8Net"
  end
  
  local valveMax = luup.variable_get(R8N_SID,R8N_MAX,R8NMODULE) or ""
  if(valveMax == "") then
    luup.variable_set(R8N_SID,R8N_MAX,VALVEMAX,R8NMODULE)
  end
  
  local program = luup.variable_get(R8N_SID,"program",R8NMODULE) or ""
  if(program == "") then
    luup.variable_set(R8N_SID,"program","OK",R8NMODULE)
  end
  
  local poll = luup.variable_get(HADEVICE_SID,HAD_POLL,R8NMODULE) or ""
  if(poll == "") then
    luup.variable_set(HADEVICE_SID, HAD_POLL, "15m", R8NMODULE)
  end
  
  local configured = luup.variable_get(HADEVICE_SID,HAD_CONFIGURED, R8NMODULE) or ""
  if(configured == "" ) then
    luup.variable_set(HADEVICE_SID, HAD_CONFIGURED, "0",R8NMODULE)
  end

  local version = luup.variable_get(R8N_SID,"Version",R8NMODULE) or 0
  
  if(tonumber(VERSION) > tonumber(version)) then
    configured = "0"
    luup.variable_set(R8N_SID, "Version", VERSION, R8NMODULE)
  end
  
  initParameter()
  r8nGlobalOff()
  
  if (configured == "" or configured == "0") then
    getModules()
  end
  
  luup.call_delay("pollTimed", 60, "", false)
  luup.call_delay("taskHandleCreate", 90, "", false)
  
    luup.register_handler("callbackHandler", "programs")
  
  return true, "Startup complete", "Rain8Net"
end
--------------------------------------------------------------------------------
--Blank line below--

