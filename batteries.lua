--[[
	batteries for lua

	a collection of helpful code to get your project off the ground faster
]]

--setup debugger
if os.getenv("DEBUG") then
  local dbg = require("debugger")
  _G.dbg = dbg
  _G.error = dbg.error
  _G.assert = dbg.assert
else
  _G.dbg = function() end
end

--setup batteries
local _batteries = {
  --
  class = require("class"),
  --
  assert = require("assert"),
  --extension libraries
  mathx = require("mathx"),
  tablex = require("tablex"),
  stringx = require("stringx"),
  --sorting routines
  sort = require("sort"),
  --collections
  Seq = require("sequence"),
  Set = require("set"),
}

--assign aliases
for _, alias in ipairs({
  { "mathx", "math" },
  { "tablex", "table" },
  { "stringx", "string" },
  { "sort", "stable_sort" },
}) do
  _batteries[alias[2]] = _batteries[alias[1]]
end

--easy export globally if required
function _batteries:export()
  --export all key strings globally, if doesn't already exist
  for k, v in pairs(self) do
    if _G[k] == nil then
      _G[k] = v
    end
  end

  --overlay tablex and sort routines onto table
  self.tablex.shallow_overlay(table, self.tablex)
  self.sort:export()

  --overlay onto global math table
  table.shallow_overlay(math, self.mathx)

  --overlay onto string
  table.shallow_overlay(string, self.stringx)

  --overwrite assert wholesale (it's compatible)
  _G.assert = self.assert

  --like ipairs, but in reverse
  _G.ripairs = self.tablex.ripairs

  return self
end

setmetatable(_batteries, {
  __call = function(t)
    return t:export()
  end,
})

return _batteries
