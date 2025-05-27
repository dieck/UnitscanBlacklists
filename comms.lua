local L = LibStub("AceLocale-3.0"):GetLocale("UnitscanBlacklists", true)

local lastSentRAID = 0

function UnitscanBlacklists:GROUP_ROSTER_UPDATE()
	if UnitscanBlacklists.db.realm.sendGroupSync then
		-- send to RAID/GROUP only every 3 seconds
		if lastSentRAID + 3 >= time() then return 0 end 

		UnitscanBlacklists:sendBlacklist("RAID") -- sends to party if not in raid
		UnitscanBlacklists:Debug("sent list sync to RAID/GROUP")
		
		lastSentRAID = time()
	end
end

local lastSentGUILD = 0

function UnitscanBlacklists:GUILD_ROSTER_UPDATE()
	if UnitscanBlacklists.db.realm.sendPartySync then
		-- send to GUILD only every 15 seconds
		if lastSentGUILD + 15 >= time() then return 0 end 

		UnitscanBlacklists:sendBlacklist("GUILD")
		UnitscanBlacklists:Debug("sent list sync to GUILD")
		
		lastSentGUILD = time()
	end
end

-- /run UnitscanBlacklists:sendBlacklist("RAID")

function UnitscanBlacklists:sendBlacklist(channel)
	-- only send if we do have a list
	if not UnitscanBlacklists.db.realm.blacklist then return 0 end
	
	local commmsg = {
		command = "BLACKLIST_UPDATE",
		blacklist = UnitscanBlacklists.db.realm.blacklist,
	}
	UnitscanBlacklists:SendCommMessage(UnitscanBlacklists.commPrefix, UnitscanBlacklists:Serialize(commmsg), channel, nil, "BULK")
end

function UnitscanBlacklists:OnCommReceived(prefix, message, distribution, sender)
	-- only react if enabled
	if not UnitscanBlacklists.db.realm.receiveSyncs then return 0 end
	
	-- playerName may contain "-REALM"
	sender = strsplit("-", sender)

	-- don't react to own messages
	if sender == UnitName("player") then
		return 0
	end

    local success, deserialized = UnitscanBlacklists:Deserialize(message);

	if success then

		-- only react to addon commands
		if deserialized["command"] ~= "BLACKLIST_UPDATE" then return 0 end
		
		local newblacklist = deserialized["blacklist"]
		
		-- initialize, if never happened before
		if not UnitscanBlacklists.db.realm.blacklist then UnitscanBlacklists.db.realm.blacklist = {} end
		
		-- remove current entries
		UnitscanBlacklists:OnDisable()


		UnitscanBlacklists:Debug("Received updated blacklist data from " .. sender)

		local newEntries = {}
		local missingEntries = {}
		local updatesEntries = {}

		-- look for missing entries (already exist, but not in new list
		for blName, blEntry in pairs(UnitscanBlacklists.db.realm.blacklist) do
			if not newblacklist[blName] then
				table.insert(missingEntries, blName)
			end
		end

		-- not only new - we are also deleting those that are not existing in sync
		if not UnitscanBlacklists.db.realm.receiveSyncsNewOnly then
			-- We can't delete while looping over the db blacklist, but: not iterating anymore, so let's remove!
			
			for i, blName in ipairs(missingEntries) do
				UnitscanBlacklists:Debug("Remove " .. blName)
				UnitscanBlacklists.db.realm.blacklist[blName] = nil
			end
			if #missingEntries > 0 then
				UnitscanBlacklists:Debug("Removed " .. tostring(#missingEntries) .. " missing entries: " .. table.concat(missingEntries, ", "))
			end
		end

		-- handle new entries
		for blName, blEntry in pairs(newblacklist) do
			if UnitscanBlacklists.db.realm.blacklist[blName] then
				table.insert(updatesEntries, blName)
			else
				table.insert(newEntries, blName)
			end
			UnitscanBlacklists.db.realm.blacklist[blName] = blEntry
		end
		
		if #newEntries > 0 then
			UnitscanBlacklists:Debug("Added " .. tostring(#newEntries) .. " new entries: " .. table.concat(newEntries, ", "))
		end

		if #updatesEntries > 0 then
			UnitscanBlacklists:Debug("Updated " .. tostring(#updatesEntries) .. " existing entries: " .. table.concat(updatesEntries, ", "))
		end

		-- add updated entries
		UnitscanBlacklists:OnEnable()


	end

end