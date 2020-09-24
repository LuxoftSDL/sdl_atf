--- Module which is responsible for creating ATF xml reports
--
-- *Dependencies:* `xml`, `atf.stdlib.std.io`
--
-- *Globals:* `config`
-- @module reporter
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local xml = require('xml')
local io = require('atf.stdlib.std.io')

--- Singleton table which is used for perform all reporting activities for ATF report.
-- @table Reporter
-- @tfield string timestamp Current date + time (timestamp)
-- @tfield userdata ndoc XML builder
-- @tfield userdata root Root node of XML report
-- @tfield string curr_report_name Current report name
local Reporter = {
  timestamp = '',
  ndoc = {},
  curr_node = {},
  root = {},
  curr_report_name = {},
  mt = {_index = {}}
}

local escape_lua_pattern
do
  local matches =
  {
    ["'"] = "%'";
    ["#"] = "";
    ["&"] = "";
  }

  escape_lua_pattern = function(s)
    return (s:gsub(".", matches))
  end
end

--- Build string representation of object
-- @tparam ? o Object
-- @treturn string String representation of object
local function dump(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '\''..k..'\'' end
      s = s .. '['..k..'] = \'' .. dump(v) .. '\','
    end
    return s .. '}'
  elseif string.match(tostring(o),'[%Wxyz]') then
    return escape_lua_pattern(tostring(o))
  end
  return tostring(o)
end

--- Add test step to report
-- @tparam string name Test step name
function Reporter.AddCase(name)
  if(not config.excludeReport) then
    Reporter.curr_node = Reporter.root:addChild(name)
    Reporter.ndoc:write(Reporter.curr_report_name)
  end
end

--- Add message to report
-- @tparam string name Test step name
-- @tparam string|table funcName RPC name or table
-- @tparam table ... RPC Data
function Reporter.AddMessage(name,funcName,...)
  if(not config.excludeReport) then
    local attrib = table.pack(...)[1]
    local msg = Reporter.curr_node:addChild(name)

    if (type(funcName) ~= 'table') then
      msg:attr('FunctionName',funcName)
    else
      for an, av in pairs(funcName) do
        msg:attr(an,av)
      end
    end
    if (type(attrib) == 'table') then
      msg:text(dump(attrib))
    elseif(attrib ~= nil) then
      msg:text(attrib)
    end
    Reporter.ndoc:write(Reporter.curr_report_name)
  end
end

--- Add test step related message to report
-- @tparam string name Test step name
-- @tparam table ... Data
function Reporter.CaseMessageTotal(name, ... )
  if(not config.excludeReport) then
    local attrib = table.pack(...)[1]
    for attr_n,attr_v in pairs(attrib) do
      if (type(attr_v) == 'table') then attr_v = table.concat(attr_v, ';')
      elseif (type(attr_v) ~= 'string') then attr_v = tostring(attr_v)
      end
      Reporter.curr_node:attr(attr_n, attr_v)
    end
  end
end

--- Finalize report
function Reporter.finalize()
  if(not config.excludeReport) then
    Reporter.ndoc:write(Reporter.curr_report_name)
  end
end

--- Initialization of reporter
-- @treturn Reporter ATF reporter
function Reporter.init()
  if(config.excludeReport) then return Reporter end
  if (Reporter.timestamp == '') then Reporter.timestamp = tostring(os.date('%Y%m%d%H%M%S', os.time())) end

  local curr_report_dir
  if (config.reportPath ~= nil and config.reportPath ~= '') then
    curr_report_dir = config.reportPath .. '/XMLReports'
  else
    curr_report_dir = 'XMLReports'
  end
  local curr_report_path = curr_report_dir ..'_'..Reporter.timestamp
  Reporter.curr_report_name = io.catfile(curr_report_path, 'XML.xml')
  os.execute('mkdir -p "'.. curr_report_path .. '"')
  Reporter.ndoc = xml.new()
  Reporter.root = Reporter.ndoc:createRootNode("root")
  return Reporter
end

return Reporter
