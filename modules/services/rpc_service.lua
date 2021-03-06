--- Module which provides RPCService type
--
-- *Dependencies:* `atf.util`, `function_id`, `json`, `protocol_handler.ford_protocol_constants`, `events`, `expectations`, `load_schema`
--
-- *Globals:* `xmlReporter`, `event_dispatcher`, `compareValues`
-- @module services.rpc_service
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

require('atf.util')

local functionId = require('function_id')
local json = require('json')
local constants = require('protocol_handler/ford_protocol_constants')
local securityConstants = require('security/security_constants')
local events = require('events')
local expectations = require('expectations')
local load_schema = require('load_schema')
local mob_schema = load_schema.mob_schema
local Expectation = expectations.Expectation
local Event = events.Event

local RpcService = {}
local mt = { __index = { } }

--- Type which represents RPC service
-- @type RPCService

--- Basic function to create expectation for request from SDL and register it in expectation list
-- @tparam RPCService RPCService Instance of RPCService
-- @tparam string funcName Function name
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
local function baseExpectRequest(RPCService, funcName, ...)
  local tbl_corr_id = {}
  local args = table.pack(...)
  local requestEvent = Event()
  if type(funcName) ~= 'string' and type(funcName) ~= 'number' then
    error("ExpectResponse: argument 1 (funcName) must be string")
    return nil
  end
  requestEvent.matches = function(_, data)
    return ((type(funcName) == 'string' and data.rpcFunctionId == functionId[funcName]) 
         or (type(funcName) == 'number' and data.rpcFunctionId == funcName))
      and data.sessionId == RPCService.session.sessionId.get()
      and data.rpcType == constants.BINARY_RPC_TYPE.REQUEST
  end
  local ret = RPCService.session:ExpectEvent(requestEvent, funcName .. " request")
  if #args > 0 then
    ret:ValidIf(function(exp, data)
        local arguments
        if exp.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[exp.occurences]
        end
        xmlReporter.AddMessage("EXPECT_REQUEST",{["id"] = tostring(cor_id),["name"] = tostring(func_name),["Type"]= "EXPECTED_RESULT"}, arguments)
        xmlReporter.AddMessage("EXPECT_REQUEST",{["id"] = tostring(cor_id),["name"] = tostring(func_name),["Type"]= "AVAILABLE_RESULT"}, data.payload)

        if type(funcName) == 'string' then
          local _res, _err = mob_schema:Validate(func_name, load_schema.response, data.payload)

          if (not _res) then return _res, _err end
        end
        return compareValues(arguments, data.payload, "payload")
      end)
  end
  return ret
end

--- Basic function to create expectation for response from SDL and register it in expectation list
-- @tparam RPCService RPCService Instance of RPCService
-- @tparam number cor_id Correlation identificator
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
local function baseExpectResponse(RPCService, cor_id, ...)
  local temp_cor_id = cor_id
  local func_name = RPCService.session.cor_id_func_map[cor_id]
  local tbl_corr_id = {}
  if func_name then
    RPCService.session.cor_id_func_map[cor_id] = nil
  else
    if type(cor_id) == 'string' then
      for fid, fname in pairs(RPCService.session.cor_id_func_map) do
        if fname == cor_id then
          func_name = fname
          table.insert(tbl_corr_id, fid)
          table.removeKey(RPCService.session.cor_id_func_map, fid)
        end
      end
      cor_id = tbl_corr_id[1]
    end
    if not func_name then
      print("Function with cor_id : ".. tostring(temp_cor_id) .." was not sent by ATF")
    end
  end
  local args = table.pack(...)
  local responseEvent = Event()
  if type(cor_id) ~= 'number' then
    error("ExpectResponse: argument 1 (cor_id) must be number")
    return nil
  end
  if(#tbl_corr_id > 0) then
    responseEvent.matches = function(_, data)
        for _, v in pairs(tbl_corr_id) do
          if data.rpcCorrelationId == v 
              and data.sessionId == RPCService.session.sessionId.get()
              and data.rpcType == constants.BINARY_RPC_TYPE.RESPONSE then
            return true
          end
        end
        return false
      end
  else
    responseEvent.matches = function(_, data)
        return data.rpcCorrelationId == cor_id
          and data.sessionId == RPCService.session.sessionId.get()
          and data.rpcType == constants.BINARY_RPC_TYPE.RESPONSE
      end
  end
  local ret = RPCService.session:ExpectEvent(responseEvent, "Response to " .. cor_id)
  if #args > 0 then
    ret:ValidIf(function(exp, data)
        local arguments
        if exp.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[exp.occurences]
        end
        xmlReporter.AddMessage("EXPECT_RESPONSE",{["id"] = tostring(cor_id),["name"] = tostring(func_name),["Type"]= "EXPECTED_RESULT"}, arguments)
        xmlReporter.AddMessage("EXPECT_RESPONSE",{["id"] = tostring(cor_id),["name"] = tostring(func_name),["Type"]= "AVAILABLE_RESULT"}, data.payload)
        if type(funcName) == 'string' then
          local _res, _err = mob_schema:Validate(func_name, load_schema.response, data.payload)

          if (not _res) then return _res, _err end
        end
        return compareValues(arguments, data.payload, "payload")
      end)
  end
  return ret
end

--- Basic function to create expectation for notification from SDL and register it in expectation list
-- @tparam RPCService RPCService Instance of RPCService
-- @tparam string funcName Notification name
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
local function baseExpectNotification(RPCService, funcName, ...)
  local notificationEvent = Event()
  notificationEvent.matches = function(_, data)
    return data.rpcFunctionId == functionId[funcName]
      and data.sessionId == RPCService.session.sessionId.get()
      and data.rpcType == constants.BINARY_RPC_TYPE.NOTIFICATION
  end
  local args = table.pack(...)

  if #args ~= 0 and (#args[1] > 0 or args[1].n == 0) then
    -- These conditions need to validate expectations received from EXPECT_NOTIFICATION
    -- Second condition - to put out array with expectations which already packed in table
    -- Third condition - to put out expectation without parameters
    -- Only args[1].n == 0 allow to validate notifications without parameters from EXPECT_NOTIFICATION
    args = args[1]
  end

  local ret = RPCService.session:ExpectEvent(notificationEvent, funcName .. " notification")
  if #args > 0 then
    args = table.removeKey(args,'notifyId')
    ret:ValidIf(function(exp, data)
        local arguments
        if exp.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[exp.occurences]
        end
        RPCService.session.notification_counter = RPCService.session.notification_counter + 1
        xmlReporter.AddMessage("EXPECT_NOTIFICATION",{["Id"] = RPCService.session.notification_counter,
          ["name"] = tostring(funcName),["Type"]= "EXPECTED_RESULT"}, arguments)
        xmlReporter.AddMessage("EXPECT_NOTIFICATION",{["Id"] = RPCService.session.notification_counter,
          ["name"] = tostring(funcName),["Type"]= "AVAILABLE_RESULT"}, data.payload)
        local _res, _err = mob_schema:Validate(funcName, load_schema.notification, data.payload)
        if (not _res) then
          return _res,_err
        end
        return compareValues(arguments, data.payload, "payload")
    end)
  end
  return ret
end

--- Construct instance of RPCService type
-- @tparam MobileSession session Mobile session
-- @treturn RPCService Constructed instance
function RpcService.RPCService(session)
  local res = { }
  res.session = session
  res.session.notification_counter = 0
  res.session.cor_id_func_map = { }
  setmetatable(res, mt)
  return res
end

--- Check correlation id in message and correct it if needed
-- @tparam table message Service message
function mt.__index:CheckCorrelationID(message)
  local message_correlation_id
  if message.rpcCorrelationId then
    message_correlation_id = message.rpcCorrelationId
  else
    local cor_id = self.session.correlationId.get()
    self.session.correlationId.set(cor_id + 1)
    message_correlation_id = cor_id
  end
  if not self.session.cor_id_func_map[message_correlation_id] then
    for fname, fid in pairs(functionId) do
      if fid == message.rpcFunctionId then
        self.session.cor_id_func_map[message_correlation_id] = fname
        break
      end
    end
    if not self.session.cor_id_func_map[message_correlation_id] then
      self.session.cor_id_func_map[message_correlation_id] = message.rpcFunctionId
    end
  else
    print("RPC service Warning: Message with correlationId: " .. message_correlation_id
      .. " in session " .. self.session.sessionId.get() .. " was sent earlier by ATF")
  end
end

--- Find function id by function name
-- @tparam string func Function name
-- @treturn number Found id
local function setFunctionId(func)
  local id = functionId[func]
  if not id then
    print("RPC service Warning: Function: " .. func .. " was not found in Mobile API")
  end
  return id
end

--- Send RPC message
-- @tparam string func Mobile function name
-- @tparam table arguments RPC parameters
-- @tparam string fileName RPC binary data
-- @tparam boolean encrypt If True RPC payload will be encrypted
-- @treturn number Correlation id
function mt.__index:SendRPC(func, arguments, fileName, encrypt)
  local encryptFlag = false
  if encrypt == securityConstants.ENCRYPTION.ON then encryptFlag = true end
  self.session.correlationId.set(self.session.correlationId.get() + 1)
  local correlationId = self.session.correlationId.get()
  local functionId
  if type(func) == 'string' then
    functionId = setFunctionId(func)
  elseif type(func) == 'number' then
    functionId = func
  end
  local msg =
  {
    encryption = encryptFlag,
    serviceType = constants.SERVICE_TYPE.RPC,
    frameInfo = 0,
    rpcType = constants.BINARY_RPC_TYPE.REQUEST,
    rpcFunctionId = functionId,
    rpcCorrelationId = correlationId,
    payload = json.encode(arguments)
  }
  self:CheckCorrelationID(msg)
  if fileName then
    local f = assert(io.open(fileName))
    msg.binaryData = f:read("*all")
    io.close(f)
  end
  self.session:Send(msg)

  return correlationId
end

--- Send RPC response
-- @tparam string func Mobile function name
-- @tparam number cor_id Correlation identifier
-- @tparam table arguments RPC parameters
-- @tparam string fileName RPC binary data
-- @tparam boolean encrypt If True RPC payload will be encrypted
function mt.__index:SendResponse(func, cor_id, arguments, fileName, encrypt)
  local encryptFlag = false
  if encrypt == securityConstants.ENCRYPTION.ON then encryptFlag = true end
  local correlationId = cor_id
  local functionId
  if type(func) == 'string' then
    functionId = setFunctionId(func)
  elseif type(func) == 'number' then
    functionId = func
  end
  local msg =
  {
    encryption = encryptFlag,
    serviceType = constants.SERVICE_TYPE.RPC,
    frameInfo = 0,
    rpcType = constants.BINARY_RPC_TYPE.RESPONSE,
    rpcFunctionId = functionId,
    rpcCorrelationId = correlationId,
    payload = json.encode(arguments)
  }
  if fileName then
    local f = assert(io.open(fileName))
    msg.binaryData = f:read("*all")
    io.close(f)
  end
  self.session:Send(msg)

  return correlationId
end

--- Send RPC notification
-- @tparam string func Mobile function name
-- @tparam table arguments RPC parameters
-- @tparam string fileName RPC binary data
-- @tparam boolean encrypt If True RPC payload will be encrypted
function mt.__index:SendNotification(func, arguments, fileName, encrypt)
  local encryptFlag = false
  if encrypt == securityConstants.ENCRYPTION.ON then encryptFlag = true end
  local msg =
  {
    encryption = encryptFlag,
    serviceType = constants.SERVICE_TYPE.RPC,
    frameInfo = 0,
    rpcType = constants.BINARY_RPC_TYPE.NOTIFICATION,
    rpcFunctionId = setFunctionId(func),
    rpcCorrelationId = -1,
    payload = json.encode(arguments)
  }
  if fileName then
    local f = assert(io.open(fileName))
    msg.binaryData = f:read("*all")
    io.close(f)
  end
  self.session:Send(msg)
end

--- Create expectation for request from SDL and register it in expectation list
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
function mt.__index:ExpectRequest(funcName, ...)
  return baseExpectRequest(self, funcName, ...)
  :ValidIf(function(_, data)
      if data._technical.decryptionStatus ~= securityConstants.SECURITY_STATUS.NO_ENCRYPTION then
        print("Expected not encrypted message. Received encrypted or corrupted message.")
        print("Decryption status is: " .. data._technical.decryptionStatus)
        return false
      end
      return true
    end)
end

--- Create expectation for response from SDL and register it in expectation list
-- @tparam number cor_id Correlation identificator
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
-- @todo (VVeremjova) Refactore according APPLINK-16802
function mt.__index:ExpectResponse(cor_id, ...)
  return baseExpectResponse(self, cor_id, ...)
  :ValidIf(function(_, data)
      if data._technical.decryptionStatus ~= securityConstants.SECURITY_STATUS.NO_ENCRYPTION then
        print("Expected not encrypted message. Received encrypted or corrupted message.")
        print("Decryption status is: " .. data._technical.decryptionStatus)
        return false
      end
      return true
    end)
end

--- Create expectation for notification from SDL and register it in expectation list
-- @tparam string funcName Notification name
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
-- @todo (VVeremjova) Refactore according APPLINK-16802
function mt.__index:ExpectNotification(funcName, ...)
  return baseExpectNotification(self, funcName, ...)
  :ValidIf(function(_, data)
      if data._technical.decryptionStatus ~= securityConstants.SECURITY_STATUS.NO_ENCRYPTION then
        print("Expected not encrypted message. Received encrypted or corrupted message.")
        return false
      end
      return true
    end)
end

--- Create expectation for encrypted request from SDL and register it in expectation list
-- @tparam string funcName Request name
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
function mt.__index:ExpectEncryptedRequest(funcName, ...)
  return baseExpectRequest(self, funcName, ...)
  :ValidIf(function(_, data)
      if data._technical.decryptionStatus ~= securityConstants.SECURITY_STATUS.SUCCESS then
        print("Expected encrypted message. Received not encrypted or corrupted message.")
        print("Decryption status is: " .. data._technical.decryptionStatus)
        return false
      end
      return true
    end)
end

--- Create expectation for encrypted response from SDL and register it in expectation list
-- @tparam number cor_id Correlation identificator
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
function mt.__index:ExpectEncryptedResponse(cor_id, ...)
  return baseExpectResponse(self, cor_id, ...)
  :ValidIf(function(_, data)
      if data._technical.decryptionStatus ~= securityConstants.SECURITY_STATUS.SUCCESS then
        print("Expected encrypted message. Received not encrypted or corrupted message.")
        print("Decryption status is: " .. data._technical.decryptionStatus)
        return false
      end
      return true
    end)
end

--- Create expectation for encrypted notification from SDL and register it in expectation list
-- @tparam string funcName Notification name
-- @tparam table ... Expectations parameters
-- @treturn Expectation Created expectation
function mt.__index:ExpectEncryptedNotification(funcName, ...)
  return baseExpectNotification(self, funcName, ...)
  :ValidIf(function(_, data)
      if data._technical.decryptionStatus ~= securityConstants.SECURITY_STATUS.SUCCESS then
        print("Expected encrypted message. Received not encrypted or corrupted message.")
        print("Decryption status is: " .. data._technical.decryptionStatus)
        return false
      end
      return true
    end)
end

return RpcService
