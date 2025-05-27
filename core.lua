local L = LibStub("AceLocale-3.0"):GetLocale("UnitscanBlacklists", true)

local UnitscanBlacklistsCommPrefix = "unscblacklist001"

local defaults = {
  realm = {
    debug = false,
	receiveSyncs = true,
	receiveSyncsNewOnly = false,
	sendGroupSync = true,
	sendGuildSync = true,
  }
}

function UnitscanBlacklists:RegisterEvents() 
  if UnitscanBlacklists.db.realm.sendGuildSync then
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
  else
	self:UnregisterEvent("GUILD_ROSTER_UPDATE")
  end

  if UnitscanBlacklists.db.realm.sendGroupSync then
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
  else
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
  end
end

function UnitscanBlacklists:OnInitialize()
  -- Code that you want to run when the addon is first loaded goes here.
  self.db = LibStub("AceDB-3.0"):New("UnitscanBlacklistDB", defaults)

  self.commPrefix = UnitscanBlacklistsCommPrefix

  LibStub("AceConfig-3.0"):RegisterOptionsTable("UnitscanBlacklists", self.blOptionsTable)
  self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("UnitscanBlacklists", "UnitscanBlacklists")

  -- communicate between addons
  self:RegisterComm(self.commPrefix, "OnCommReceived")

  -- only register events after initializing all other variables
  UnitscanBlacklists:RegisterEvents()
end



function UnitscanBlacklists:OnEnable()

	local onShowFct = 	function(blname)
			local bl = UnitscanBlacklists:GetBlacklist(blname)
			UnitscanBlacklists:Print("BLACKLISTED! " .. bl)
		end
	local tbl = { onShow = onShowFct, subtitle = "Player Blacklisted" }

	if UnitscanBlacklists.db.realm.blacklist == nil then return end
	for blName, d in pairs(UnitscanBlacklists.db.realm.blacklist) do
		unitscan_targets[blName] = tbl
	end

end

function UnitscanBlacklists:OnEnable2()
    -- Called when the addon is enabled - but delay until player is loaded, so unitscan will certainly be available
	local frame = CreateFrame("Frame")
	frame:SetScript("OnEvent", function(__, event, ...)
		if (event == "PLAYER_ENTERING_WORLD") then
			frame:UnregisterEvent("PLAYER_ENTERING_WORLD")
			UnitscanBlacklists:manualEnable()
		end
	end)
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function UnitscanBlacklists:OnDisable()
    -- Called when the addon is disabled
	if UnitscanBlacklists.db.realm.blacklist == nil then return end
	for blName, d in pairs(UnitscanBlacklists.db.realm.blacklist) do
		unitscan_targets[blName] = nil
	end
end

-- for debug outputs
function tprint (tbl, indent)
	if not indent then indent = 0 end
	local toprint = string.rep(" ", indent) .. "{\r\n"
	indent = indent + 2
	for k, v in pairs(tbl) do
	  toprint = toprint .. string.rep(" ", indent)
	  if (type(k) == "number") then
		toprint = toprint .. "[" .. k .. "] = "
	  elseif (type(k) == "string") then
		toprint = toprint  .. k ..  "= "
	  end
	  if (type(v) == "number") then
		toprint = toprint .. v .. ",\r\n"
	  elseif (type(v) == "string") then
		toprint = toprint .. "\"" .. v .. "\",\r\n"
	  elseif (type(v) == "table") then
		toprint = toprint .. tprint(v, indent + 2) .. ",\r\n"
	  else
		toprint = toprint .. "\"" .. tostring(v) .. "\",\r\n"
	  end
	end
	toprint = toprint .. string.rep(" ", indent-2) .. "}"
	return toprint
end

function UnitscanBlacklists:tRemoveValue(t, value)
	UnitscanBlacklists:Debug("before: " .. #t)
	local idx = nil
	for i,v in pairs(t) do
		-- do not remove while iterating table
		if value == v then 
			idx = i
			UnitscanBlacklists:Debug("found value at index: " .. idx)
		end
	end
	table.remove(t, idx)
	UnitscanBlacklists:Debug("after: " .. #t)
end

local function tablesize(t)
	  local count = 0
	  for _, __ in pairs(t) do
		  count = count + 1
	  end
	  return count
end

function tempty(t)
	  if t == nil then return true end
	  if tablesize(t) > 0 then return false end
	  return true
end

-- /run UnitscanBlacklists:Debug(UnitscanBlacklists.db.realm.blacklist)
-- /run UnitscanBlacklists:Debug(unitscan.button)
-- /run UnitscanBlacklists:Debug(unitscan_targets)

function UnitscanBlacklists:GetBlacklist(blname)
	local b = blname
	local d = UnitscanBlacklists.db.realm.blacklist[blname]
	
	if d["guild"] ~= nil then b = b .. " <" .. d["guild"] .. ">" end
	if d["class"] ~= nil  then b = b .. " - " .. d["class"] end
	if d["race"] ~= nil  then b = b .. " - " .. d["race"] end
	b = b .. " - " .. d["desc"]
	
	return b
end

function UnitscanBlacklists:GetConfigBlacklist(info)
	if UnitscanBlacklists.db.realm.blacklist == nil then return "" end
    local r = {}
	for blname, d in pairs(UnitscanBlacklists.db.realm.blacklist) do
		local b = UnitscanBlacklists:GetBlacklist(blname)
		table.insert(r, b)
	end
	return table.concat(r, "\r\n")
end

function UnitscanBlacklists:SetConfigBlacklist(info, value)

	UnitscanBlacklists:OnDisable() -- will remove all former unitscan entries
	UnitscanBlacklists.db.realm.blacklist = {}

	local line = ""
	
	for matchedline in string.gmatch(value, "[^\r\n]+") do
		local line = matchedline
		UnitscanBlacklists:Debug(line)

		local blName = ""
		local blGuild = nil
		local blClass = nil
		local blRace = nil

		-- ignore comma and dashes (as long as those combinations are in
		local cnt = 1

		while cnt > 0 do 
			local cnt1, cnt2
			line, cnt1 = string.gsub(line, ", ", " ")
			line, cnt2 = string.gsub(line, " %- ", " ")
			cnt = cnt1 + cnt2
		end

		-- look for guild
		for m in string.gmatch(line, "<(.-)>") do
		  blGuild = m
		  -- remove guild from further parsing
		  line = string.gsub(line, "<.->", " ")
		end

		-- remove double entries
		line = string.gsub(line, "  ", " ")
		
		local lineitems = strsplittable(" ", line)
		
		blName = table.remove(lineitems, 1)
		
		while true do
			look = table.remove(lineitems, 1)
			s = 0
			
			-- strfind will eliminate the needs to look for plurals
			if strfind(strupper(look), "WARRIOR") then blClass = "Warrior" s=1 end
			if strfind(strupper(look), "PALA") then blClass = "Paladin" s=1 end
			if strfind(strupper(look), "HUNTER") then blClass = "Hunter" s=1 end
			if strfind(strupper(look), "ROGUE") then blClass = "Rogue" s=1 end
			if strfind(strupper(look), "PRIEST") then blClass = "Priest" s=1 end
			if strfind(strupper(look), "SHAMAN") then blClass = "Shaman" s=1 end
			if strfind(strupper(look), "MAGE") then blClass = "Mage" s=1 end
			if strfind(strupper(look), "WARLOCK") then blClass = "Warlock" s=1 end
			if strfind(strupper(look), "DRUID") then blClass = "Druid" s=1 end

			if strfind(strupper(look), "HUMAN") then blRace = "Human" s=1 end
			if strfind(strupper(look), "DWARF") then blRace = "Dwarf" s=1 end
			if strfind(strupper(look), "NIGHTELF") then blRace = "Nightelf" s=1 end
			if strfind(strupper(look), "NIGHT ELF") then blRace = "Nightelf" s=1 end
			if strfind(strupper(look), "GNOME") then blRace = "Gnome" s=1 end
			if strfind(strupper(look), "ORC") then blRace = "Orc" s=1 end
			if strfind(strupper(look), "UNDEAD") then blRace = "Undead" s=1 end
			if strfind(strupper(look), "TAUREN") then blRace = "Tauren" s=1 end
			if strfind(strupper(look), "TROLL") then blRace = "Troll" s=1 end
	
			-- found none? then we are finished looking
			if s == 0 then
				-- put the first back again
				table.insert(lineitems, 1, look)
				break 
			end
			
		end
	
		-- whatever is left, is explanatory text
		local blDesc = table.concat(lineitems, " ")

		UnitscanBlacklists.db.realm.blacklist[blName] = {
			guild = blGuild,
			race = blRace,
			class = blClass,
			desc = blDesc
		}
				
	end

	-- send out notification, if enabled
	UnitscanBlacklists:GROUP_ROSTER_UPDATE()
	UnitscanBlacklists:GUILD_ROSTER_UPDATE()

	UnitscanBlacklists:OnEnable() -- will add all unitscan global entries

end


-- -- config items

UnitscanBlacklists.blOptionsTable = {
  type = "group",
  args = {

	syncHdr = {
		name = L["Addon Sync"],
		type = "header",
		order = 10,
	},
    receiveSyncs = {
      name = L["Receive syncs"],
      desc = L["Accept incoming sync information"],
      type = "toggle",
      order = 15,
      set = function(info,val) UnitscanBlacklists.db.realm.receiveSyncs = val end,
      get = function(info) return UnitscanBlacklists.db.realm.receiveSyncs end
    },
    receiveSyncsNewOnly = {
      name = L["Only add new"],
      desc = L["Do not delete entries missing from update"],
      disabled = function() return not UnitscanBlacklists.db.realm.receiveSyncs end,
      type = "toggle",
      order = 17,
      set = function(info,val) UnitscanBlacklists.db.realm.receiveSyncsNewOnly = val end,
      get = function(info) return UnitscanBlacklists.db.realm.receiveSyncsNewOnly end
    },
	dummy19 = {
		name = "",
		type = "description",
		order = 19,
	},

    sendSyncGuild = {
      name = L["Send to Guild"],
      desc = L["Automatically send syncs when importing, and when a guild member comes online"],
      type = "toggle",
      order = 20,
      set = function(info,val) UnitscanBlacklists.db.realm.sendGuildSync = val ; UnitscanBlacklists:RegisterEvents() end,
      get = function(info) return UnitscanBlacklists.db.realm.sendGuildSync end
    },
    sendSyncParty = {
      name = L["Send to Group"],
      desc = L["Automatically send syncs when importing, and when group or raid members join or leave"],
      type = "toggle",
      order = 23,
      set = function(info,val) UnitscanBlacklists.db.realm.sendGroupSync = val ; UnitscanBlacklists:RegisterEvents() end,
      get = function(info) return UnitscanBlacklists.db.realm.sendGroupSync end
    },
	dummy29 = {
		name = "",
		type = "description",
		order = 29,
	},
	
	importHdr = {
		name = L["Import / Manage blacklist"],
		type = "header",
		order = 40,
	},
	blacklisted = {
		name = L["Blacklist"],
		desc = L["Old blacklist will be overwritten"],
		type = "input",
		order = 50,
		confirm = true,
		width = 4.0,
		multiline = 20,
		get = function(info) return UnitscanBlacklists:GetConfigBlacklist(info) end,
		set = function(info, value) UnitscanBlacklists:SetConfigBlacklist(info, value)  end,
		cmdHidden = true,
	},
	blacklistedDesc = {
		name = L["Format: Name [Class|Race|Allegiance] Cause of Blacklist"],
		type = "description",
		order = 51,
	},

	miscHdr = {
		name = L["Misc"],
		type = "header",
		order = 90,
	},

    debugging = {
      name = L["Debug"],
      desc = L["Enters Debug mode"],
      type = "toggle",
      order = 98,
      set = function(info,val) UnitscanBlacklists.db.realm.debug = val end,
      get = function(info) return UnitscanBlacklists.db.realm.debug end
    }
  } -- args
}

function UnitscanBlacklists:Debug(t, lvl)
    if lvl == nil then
	  lvl = "DEBUG"
	end
	if (UnitscanBlacklists.db.realm.debug) then
		if (type(t) == "table") then
			UnitscanBlacklists:Print(lvl .. ": " .. tprint(t))
		else
			UnitscanBlacklists:Print(lvl .. ": " .. t)
		end
	end
end