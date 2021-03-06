--[[******************************************************************************
	Addon:      Battlefield History
	Author:     Cyprias
	License:    MIT License	(http://opensource.org/licenses/MIT)
**********************************************************************************]]


local folder, core = ...
_G._BH = core

core.title		= GetAddOnMetadata(folder, "Title")
core.version	= GetAddOnMetadata(folder, "Version")
core.titleFull	= core.title.." v"..core.version
core.addonDir   = "Interface\\AddOns\\"..folder.."\\"

LibStub("AceAddon-3.0"):NewAddon(core, folder, "AceEvent-3.0", "AceSerializer-3.0", "AceBucket-3.0", "AceTimer-3.0", "AceConsole-3.0") -- "AceComm-3.0", "AceHook-3.0"

local ScrollingTable = LibStub("ScrollingTable");
local AceGUI = LibStub("AceGUI-3.0");

core.defaultSettings = {}

do
	local OnInitialize = core.OnInitialize
	function core:OnInitialize()
		if OnInitialize then OnInitialize(self) end
		self.db = LibStub("AceDB-3.0"):New("BattlefieldHistory_DB", self.defaultSettings, true) --'Default'

		self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
		self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
		self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")
		self.db.RegisterCallback(self, "OnProfileDeleted", "OnProfileChanged")
		
		self:RegisterChatCommand("bh", "ChatCommand");
		
		core.db.realm.battlefieldRounds = core.db.realm.battlefieldRounds or {};

		-- Reset battlefieldScores if no version property in db. Changing how entires are saved.
		if (type(self.db.global.version) == "nil") then
			self.db.realm.battlefieldRounds = {};
		end
		
		self.db.global.version = core.version;
	end
end

function core:ChatCommand(input)

	if not input or input:trim() == "" then
		self:OpenOptionsFrame()
	elseif input:find("score") then
		core:ShowScores();
	end
end

do
	function core:OpenOptionsFrame()
		LibStub("AceConfigDialog-3.0"):Open(core.title)
	end
end

function core:OnProfileChanged(...)	
	self:Disable() -- Shut down anything left from previous settings
	self:Enable() -- Enable again with the new settings
end

do 
	local ipairs = ipairs
	
	local OnEnable = core.OnEnable
	function core:OnEnable()
		if OnEnable then OnEnable(self) end

		self:RegisterBucketEvent("UPDATE_BATTLEFIELD_STATUS", 1, "BUCKET_BATTLEFIELD_STATUS")
		--self:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
		
		self:RegisterEvent("UPDATE_BATTLEFIELD_SCORE");
	end
end

do
	local OnDisable = core.OnDisable
	function core:OnDisable(...)
		if OnDisable then OnDisable(self, ...) end
	end
end

do
	local IsAddOnLoaded = IsAddOnLoaded
	local GetAddOnInfo = GetAddOnInfo
	local EnableAddOn = EnableAddOn
	local LoadAddOn = LoadAddOn
	local ADDON_LOAD_FAILED = ADDON_LOAD_FAILED
	
	local loaded, reason
	local _, enabled
	function core:LoadAddon(addonName, shouldEcho)
		local shouldEcho = shouldEcho or false
		if not IsAddOnLoaded(addonName) then
			_, _, _, enabled = GetAddOnInfo(addonName)
			if not enabled then
				EnableAddOn(addonName)
			end
			loaded, reason = LoadAddOn(addonName)
			if not loaded then
				if shouldEcho then
					self.echo(ADDON_LOAD_FAILED:format(addonName, reason))
				else
					self.Debug("LoadAddon", ADDON_LOAD_FAILED:format(addonName, reason))
				end
				return false
			end
		end
		return true
	end
end

function core:dump_table(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. core:dump_table(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

local strWhiteBar		= "|cffffff00 || |r" -- a white bar to seperate the debug info.
local echo
do
	local colouredName		= "|cff008000BH:|r "

	local tostring = tostring
	local select = select
	local _G = _G

	local msg
	local part
	
	local cf
	function echo(...)
		msg = tostring(select(1, ...))
		for i = 2, select("#", ...) do
			part = select(i, ...)
			msg = msg..strWhiteBar..tostring(part)
		end
		
		cf = _G["ChatFrame1"]
		if cf then
			cf:AddMessage(colouredName..msg,.7,.7,.7)
		end
	end
	core.echo = echo

	local strDebugFrom		= "|cffffff00[%s]|r" --Yellow function name. help pinpoint where the debug msg is from.
	
	local select = select
	local tostring = tostring
	
	local msg
	local part
	local function Debug(from, ...)
		if core.db.profile.debugMessages == false then
			return
		end
		
		msg = "nil"
		if select(1, ...) then
			msg = tostring(select(1, ...))
			for i = 2, select("#", ...) do
				part = select(i, ...)
				msg = msg..strWhiteBar..tostring(part)
			end
		end
		--from
		echo(strDebugFrom:format("D").." "..msg)
	end
	core.Debug = Debug
end

do
	local GetMaxBattlefieldID = GetMaxBattlefieldID;
	local GetBattlefieldStatus = GetBattlefieldStatus;
	function core:GetBattlefieldStatus()
		local battlefieldStatus = {};
		local status, mapName, teamSize, registeredMatch, suspend
		for i=1, GetMaxBattlefieldID() do
			status, mapName, teamSize, registeredMatch, suspend = GetBattlefieldStatus(i);
			table.insert(battlefieldStatus, {
				i = i,
				status              = status,
				mapName             = mapName,
				teamSize            = teamSize,
				registeredMatch     = registeredMatch,
				suspend             = suspend
			})
		end
		return battlefieldStatus;
	end
end

do
	local IsActiveBattlefieldArena = IsActiveBattlefieldArena;
	local GetBattlefieldWinner = GetBattlefieldWinner;
	local GetBattlefieldInstanceRunTime = GetBattlefieldInstanceRunTime;

	local function onScores(params)
		core:Debug("<ProcessBattlefieldStatusChange|onScores>");
		
		local forward = params.forward;
		local roundScores = params.roundScores;

		local mapName = forward.mapName;
		local battlefieldWinner = forward.battlefieldWinner;
		local inArena = forward.inArena;
		local runtime = forward.runtime;

		core.Debug("ProcessBattlefieldStatusChange", "battlefieldWinner: " .. tostring(battlefieldWinner) .. ", inArena: " .. tostring(inArena));

		if ( not inArena and battlefieldWinner ) then

			

			--local scores = core:GetBattlefieldScores();
			-- Pass it to save function.
			core:RecordBattlefieldScores({
				--scores = scores,
				scores = roundScores,
				mapName = mapName,
				runtime = runtime,
				battlefieldWinner = battlefieldWinner,
			});
		end
	end
	
	function core:ProcessBattlefieldStatusChange(params)
		core.Debug("ProcessBattlefieldStatusChange", "<ProcessBattlefieldStatusChange>");
		local battlefieldStatus     = params.battlefieldStatus or {[1]={status="active"}};
		local inArena               = params.inArena or IsActiveBattlefieldArena();
		local battlefieldWinner     = params.battlefieldWinner or GetBattlefieldWinner();
		local runtime               = params.runtime or GetBattlefieldInstanceRunTime();

		local s;
		for i = 1, table.getn(battlefieldStatus) do 
			s = battlefieldStatus[i];
			core:Debug("i: " .. tostring(i) .. ", status: " .. tostring(s.status));
			if ( s.status == "active") then
				-- Request fresh scores.
				core:RequestBattlefieldScoreData({
					forward = {
						mapName = s.mapName,
						battlefieldWinner = battlefieldWinner,
						inArena = inArena,
						runtime = runtime,
					}
				}, onScores);
			end
		end
	end
end

do
	local RequestBattlefieldScoreData = RequestBattlefieldScoreData;
	
	local roundScores;
	local function UpdateRoundScores()
		core:Debug("<UpdateRoundScores>");
		roundScores = roundScores or {};
		local scores = core:GetBattlefieldScores();
		local playerCount = 0;
		local myFaction;
		
		for name, score in pairs(scores) do
			roundScores[ name ] = roundScores[ name ] or {};

			for k, v in pairs(score) do
				roundScores[ name ][k] = v;
			end
			roundScores[ name ].firstSeen = roundScores[ name ].firstSeen or GetTime(); -- First seen.
			roundScores[ name ].lastSeen = GetTime();
			
			playerCount = playerCount + 1;
			
			if (name == UnitName("player")) then
				myFaction = score.faction;
			end
		end
		
		-- Check for players that have quit.
		local quitNames = {};
		for name, score in pairs(roundScores) do
			if (type(scores[ name ]) == "nil") then
				if (roundScores[name].quit ~= true and roundScores[name].faction ~= myFaction) then
					table.insert(quitNames, name)
				end
				roundScores[name].quit = true;
			end
		end
		
		core:Debug("quitNames: " .. table.getn(quitNames));
		
		-- Check if anyone quit before end of the round.
		if (table.getn(quitNames) > 0)  then
			core.echo(table.concat(quitNames, ",") .. " left the battleground.");
		end
		
		core:Debug("playerCount: " .. playerCount);
	end
	
	function core:RequestBattlefieldScoreData(params, callback)
		core.Debug("RequestBattlefieldScoreData", "<RequestBattlefieldScoreData>");
		
		--local mapName = params and params.mapName;
		local forward = params and params.forward;
		
		local f = CreateFrame("Frame");
	
		-- Register our event handlers.
		function onEvent(this, event, ...)
			core.Debug("RequestBattlefieldScoreData", "<onEvent>");
			
			if (f) then
				-- Unregister this event handler.
				f:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE");
				f:SetScript("OnEvent", nil);
				f = nil;
				
				core:CancelTimer(tid);
				
				UpdateRoundScores();
				
				-- Call our callback.
				callback({
					fresh = true,
					forward = forward,
					roundScores = roundScores,
				});
			end
		end
		f:SetScript("OnEvent", onEvent)
		f:RegisterEvent("UPDATE_BATTLEFIELD_SCORE");
		
		--[[ ]]
		function onTimeout()
			core.Debug("RequestBattlefieldScoreData", "<onTimeout>");
			if (f) then
				f:UnregisterEvent("UPDATE_BATTLEFIELD_SCORE");
				f:SetScript("OnEvent", nil);
				f = nil;
			
				callback({
					fresh = false,
					forward = forward,
					roundScores = roundScores,
				});
			end
		end
		
		local tid = core:ScheduleTimer(onTimeout, 1)
		--core.echo("tid: " .. tostring(tid));
		
		-- Request the info from the server.
		RequestBattlefieldScoreData();
	end
	
	
	-- Reset the roundScores table when we're not in a BG.
	function core:BUCKET_BATTLEFIELD_STATUS(...)--	/script _BH:BUCKET_BATTLEFIELD_STATUS()
		local battlefieldStatus = core:GetBattlefieldStatus();
		local inBG = false;
		local s;
		for i = 1, table.getn(battlefieldStatus) do 
			s = battlefieldStatus[i];
			if ( s.status == "active") then
				inBG = true;
				--UpdateRoundScores();
				break;
			end
		end
		
		core:Debug("inBG: " .. tostring(inBG));
		
		if (inBG == true) then
			core:ProcessBattlefieldStatusChange( {
				battlefieldStatus=battlefieldStatus 
			});
		elseif (not inBG and roundScores) then
			roundScores = nil;
			core:Debug("Cleared roundScores.");
		end

	end

	-- Refresh the round scores whenever event fires.
	function core:UPDATE_BATTLEFIELD_SCORE(...)
		UpdateRoundScores();
	end
end

do
	local GetNumBattlefieldScores = GetNumBattlefieldScores;
	local GetBattlefieldScore = GetBattlefieldScore;
	
	function core:GetBattlefieldScores( params )
	
		local scores = {};
	
		local name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone, bgRating, ratingChange, preMatchMMR, mmrChange, talentSpec;
		local text, icon, tooltip;
		local playerData;
		for i=1, GetNumBattlefieldScores() do
			name, killingBlows, honorableKills, deaths, honorGained, faction, race, class, classToken, damageDone, healingDone, bgRating, ratingChange, preMatchMMR, mmrChange, talentSpec = GetBattlefieldScore(i);
			
			-- Strip '-' from the name.
			if (string.find(name,"-")) then
				local intEnd = string.find(name, "-");
				name	= string.sub(name, 1, intEnd - 1);
			end
			
			playerData = {
			--	i                   = i,
				name                = name,
				killingBlows        = killingBlows,
				honorableKills      = honorableKills,
				deaths              = deaths,
				honorGained         = honorGained,
				faction             = faction,
				race                = race,
				class               = class,
				--classToken          = classToken,
				damageDone          = damageDone,
				healingDone         = healingDone,
				bgRating            = bgRating,
				ratingChange        = ratingChange,
				preMatchMMR         = preMatchMMR,
				mmrChange           = mmrChange,
				talentSpec          = talentSpec,
			};

			--core.echo("name: " .. name .. ", stats: " .. GetNumBattlefieldStats());
			
			for j=1, GetNumBattlefieldStats() do
				text, icon, tooltip = GetBattlefieldStatInfo(j);

				columnData = GetBattlefieldStatData(i, j);
				--core.echo("name: " .. name .. ", stat " .. text .. " (" .. j .. "): " .. columnData);
				
				playerData[text] = columnData;
			end

			--table.insert(scores, playerData)
			scores[name] = playerData;
		end
		return scores;
	end	
end

do
	function core:uuid()
		local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
		return string.gsub(template, '[xy]', function (c)
			local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
			return string.format('%x', v)
		end)
	end
end

do
	local time = time; -- time() returns unixtime.
	local GetTime = GetTime;
	
	local lastSaveTime = 0;
	function core:RecordBattlefieldScores(params)
		local scores = params.scores;
		local elapsed = GetTime() - lastSaveTime;
		core.Debug("RecordBattlefieldScores", "elapsed: " .. elapsed);
		--core.echo("battlefieldWinner: " .. battlefieldWinner);
		
		
		if (elapsed < 30) then
			core:Debug("It's only been " .. elapsed .. " is our last record save.");
			return;
		end
		
		self.db.realm.battlefieldRounds = self.db.realm.battlefieldRounds or {};
		
		local payload = {};
		payload.mapName             = params.mapName;
		payload.runtime             = params.runtime;
		payload.battlefieldWinner   = params.battlefieldWinner;
		payload.time                = params.time or time();
		payload.scores              = scores;

		
		payload.totalDamageDone = 0;
		payload.totalHealingDone = 0;
		for name, score in pairs(scores) do
			if (score.damageDone) then
				payload.totalDamageDone = payload.totalDamageDone + score.damageDone;
			end
			if (score.healingDone) then
				payload.totalHealingDone = payload.totalHealingDone + score.healingDone;
			end
			
			score.playTime = score.lastSeen - score.firstSeen;
			core:Debug("name: " .. tostring(name) .. " firstSeen: " .. tostring(score.firstSeen) .. ", lastSeen: " .. tostring(score.lastSeen) .. " playTime: " .. tostring(score.playTime) .. ", quit: " .. tostring(score.quit));
		end
		
		
		table.insert(self.db.realm.battlefieldRounds, core:Serialize(payload));
		core.echo("Saved battlefield stats.");
		lastSaveTime = GetTime();
	end
	
end

local shownData;
do
	local col_Name	    = 1;
	local col_DR        = 2;
	local col_DP        = 3;
	local col_HR        = 4;
	local col_HP        = 5;
	local col_Wins      = 6;
	local col_Rounds    = 7;
	
	local allCols = {
		{ name= "Name", width = 100, defaultsort = "dsc", },
		--{ name= "Killing Blows", width = 100, defaultsort = "dsc", },
		--{ name= "Deaths", width = 80, defaultsort = "dsc", }, -- Deaths
		--{ name= "Honerable Kills", width = 80, defaultsort = "dsc", }, -- honorKills
		
		{ name= "DR", width = 60, defaultsort = "dsc", 
			["comparesort"] = function (self, rowa, rowb, sortbycol)

				if (not shownData[rowa]) then
					return false;
				elseif (not shownData[rowb]) then
					return true;
				end
			
				if (not shownData[rowa].cols[sortbycol] and not shownData[rowb].cols[sortbycol]) then
					return shownData[rowa].cols[col_Name].value < shownData[rowb].cols[col_Name].value;
				elseif (not shownData[rowa].cols[sortbycol]) then
					return false;
				elseif (not shownData[rowb].cols[sortbycol]) then
					return true;
				end
			
				if self.cols[sortbycol].sort == "dsc" then
					return shownData[rowa].cols[sortbycol].args[1] < shownData[rowb].cols[sortbycol].args[1]
				else
					return shownData[rowa].cols[sortbycol].args[1] > shownData[rowb].cols[sortbycol].args[1]
				end
			end,
		}, 

		{ name= "DP", width = 60, defaultsort = "dsc", 
			["comparesort"] = function (self, rowa, rowb, sortbycol)
			
				if (not shownData[rowa]) then
					return false;
				elseif (not shownData[rowb]) then
					return true;
				end
			
				if (not shownData[rowa].cols[sortbycol] and not shownData[rowb].cols[sortbycol]) then
					return shownData[rowa].cols[col_Name].value < shownData[rowb].cols[col_Name].value;
				elseif (not shownData[rowa].cols[sortbycol]) then
					return false;
				elseif (not shownData[rowb].cols[sortbycol]) then
					return true;
				end
			
				if self.cols[sortbycol].sort == "dsc" then
					return shownData[rowa].cols[sortbycol].args[1] < shownData[rowb].cols[sortbycol].args[1]
				else
					return shownData[rowa].cols[sortbycol].args[1] > shownData[rowb].cols[sortbycol].args[1]
				end
			end,
		}, 
		
		{ name= "HR", width = 60, defaultsort = "dsc", 
			["comparesort"] = function (self, rowa, rowb, sortbycol)
			
				if (not shownData[rowa]) then
					return false;
				elseif (not shownData[rowb]) then
					return true;
				end
			
				if (not shownData[rowa].cols[sortbycol] and not shownData[rowb].cols[sortbycol]) then
					return shownData[rowa].cols[col_Name].value < shownData[rowb].cols[col_Name].value;
				elseif (not shownData[rowa].cols[sortbycol]) then
					return false;
				elseif (not shownData[rowb].cols[sortbycol]) then
					return true;
				end
			
				if self.cols[sortbycol].sort == "dsc" then
					return shownData[rowa].cols[sortbycol].args[1] < shownData[rowb].cols[sortbycol].args[1]
				else
					return shownData[rowa].cols[sortbycol].args[1] > shownData[rowb].cols[sortbycol].args[1]
				end
			end,
		}, 

		{ name= "HP", width = 60, defaultsort = "dsc", 
			["comparesort"] = function (self, rowa, rowb, sortbycol)
			
				if (not shownData[rowa]) then
					return false;
				elseif (not shownData[rowb]) then
					return true;
				end
			
				if (not shownData[rowa].cols[sortbycol] and not shownData[rowb].cols[sortbycol]) then
					return shownData[rowa].cols[col_Name].value < shownData[rowb].cols[col_Name].value;
				elseif (not shownData[rowa].cols[sortbycol]) then
					return false;
				elseif (not shownData[rowb].cols[sortbycol]) then
					return true;
				end
			
				if self.cols[sortbycol].sort == "dsc" then
					return shownData[rowa].cols[sortbycol].args[1] < shownData[rowb].cols[sortbycol].args[1]
				else
					return shownData[rowa].cols[sortbycol].args[1] > shownData[rowb].cols[sortbycol].args[1]
				end
			end,
		}, 

		{ name= "Wins", width = 80, defaultsort = "dsc", 
			["comparesort"] = function (self, rowa, rowb, sortbycol)

				if (not shownData[rowa]) then
					return false;
				elseif (not shownData[rowb]) then
					return true;
				end
			
				if (not shownData[rowa].cols[sortbycol] and not shownData[rowb].cols[sortbycol]) then
					return shownData[rowa].cols[col_Name].value < shownData[rowb].cols[col_Name].value;
				elseif (not shownData[rowa].cols[sortbycol]) then
					return false;
				elseif (not shownData[rowb].cols[sortbycol]) then
					return true;
				end
			
				if (shownData[rowa].cols[sortbycol].args[3] == shownData[rowb].cols[sortbycol].args[3]) then
					return shownData[rowa].cols[sortbycol].args[2] > shownData[rowb].cols[sortbycol].args[2]
				end
				
				if self.cols[sortbycol].sort == "dsc" then
					return shownData[rowa].cols[sortbycol].args[3] < shownData[rowb].cols[sortbycol].args[3]
				else
					return shownData[rowa].cols[sortbycol].args[3] > shownData[rowb].cols[sortbycol].args[3]
				end

			end,
		},
		
		{ name= "Rounds", width = 80, defaultsort = "dsc", 
			["comparesort"] = function (self, rowa, rowb, sortbycol)
			
				if (not shownData[rowa]) then
					return false;
				elseif (not shownData[rowb]) then
					return true;
				end
			
				if (not shownData[rowa].cols[sortbycol] and not shownData[rowb].cols[sortbycol]) then
					return shownData[rowa].cols[col_Name].value < shownData[rowb].cols[col_Name].value;
				elseif (not shownData[rowa].cols[sortbycol]) then
					return false;
				elseif (not shownData[rowb].cols[sortbycol]) then
					return true;
				end
			
				if (shownData[rowa].cols[sortbycol].args[1] ~= shownData[rowb].cols[sortbycol].args[1]) then
					if self.cols[sortbycol].sort == "dsc" then
						return shownData[rowa].cols[sortbycol].args[1] < shownData[rowb].cols[sortbycol].args[1]
					else
						return shownData[rowa].cols[sortbycol].args[1] > shownData[rowb].cols[sortbycol].args[1]
					end
				else
					return shownData[rowa].cols[ col_Wins ].args[1] > shownData[rowb].cols[ col_Wins ].args[1]
				end
			end,
		},
		--{ name= "Honor Gained", width = 80, defaultsort = "dsc", }, -- honorGained
	}
	
	local function onGroupSelected(container, event, group)
		--core.echo("<onGroupSelected> group: " .. group);
		container:ReleaseChildren()

		if container.allST then container.allST:Hide() 	end
		if container.battlefieldST then container.battlefieldST:Hide() 	end
		if container.tmST then container.tmST:Hide() 	end
		

		if group == "tab1" then
			DrawBattlefieldContainer({container=container})
		elseif group == "tab4" then
			DrawAllContainer({container=container})
		end
	end
	
	
	
	local battlefieldTableData;
	function DrawBattlefieldContainer( params )
		local container = params.container;
		if not container.battlefieldST then
			local window  = container.frame
			container.battlefieldST = ScrollingTable:CreateST(allCols, 20, 16, nil, window)
			container.battlefieldST.frame:SetPoint("BOTTOMLEFT",window, 10,10)
			container.battlefieldST.frame:SetPoint("TOP", window, 0, -60)
			container.battlefieldST.frame:SetPoint("RIGHT", window, -10,0)
			
			container.battlefieldST:RegisterEvents({
				["OnClick"] = cellOnClick
			});
			
			--core.echo("Created allST: " .. tostring(container.allST));
		end
		container.battlefieldST:Show()

		if container.parent then
			local width = 100
			for i, data in pairs(allCols) do 
				width = width + data.width
			end
			container.parent:SetWidth(width);
		end
		
		local function onScores()
			core.Debug("DrawBattlefieldContainer", "<onScores>");
			local players = core:GetBattlefieldPlayers();
					
			shownData = RefreshTable({
				scrollTable	    = container.battlefieldST,
				players         = players,
			})
		end

		if (UnitInBattleground("player")) then
			core:RequestBattlefieldScoreData(nil, onScores);
		end
	end
	
	function cellOnClick(rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
		if (row == nil) then return; end
		
		local test = shownData[ realrow ];
		local who = test.cols[1].value;

		core:ShowPlayerStats({
			who=who
		});
	end
	
	function DrawAllContainer( params )
		local container = params.container;
		if not container.allST then
			local window  = container.frame
			container.allST = ScrollingTable:CreateST(allCols, 20, 16, nil, window)
			container.allST.frame:SetPoint("BOTTOMLEFT",window, 10,10)
			container.allST.frame:SetPoint("TOP", window, 0, -60)
			container.allST.frame:SetPoint("RIGHT", window, -10,0)
			
			container.allST:RegisterEvents({
				["OnClick"] = cellOnClick
			});
			
			--core.echo("Created allST: " .. tostring(container.allST));
		end
		container.allST:Show()
		
		if container.parent then
			local width = 100
			for i, data in pairs(allCols) do 
				width = width + data.width
			end
			container.parent:SetWidth(width);
		end
		
		--local players = core:GetBattlefieldPlayers();
		
		local allRounds = core:GetRounds();
		
		local players = {};

		--for playerName, scores in pairs(core.db.realm.battlefieldRounds) do 
		local rounds = core.db.realm.battlefieldRounds;
		local round;
		for i = 1, table.getn(allRounds) do 
			round = allRounds[i];
			for name, score in pairs(round.scores) do
				--core.echo("name: " .. tostring(name));
				table.insert(players, {
					name = name
				})
			end
		end
		
		shownData = RefreshTable({
			scrollTable	    = container.allST,
			players         = players,
			allRounds       = allRounds,
		})
	end

	--for i = 1, table.getn(scores) do 
	
	function core:GetNumKeys(object) 
		local num = 0;
		for k, v in pairs(object) do
			num = num + 1;
		end
		return num;
	end
	
	function core:GetPlayerBattlefieldStats(params)
		local name = params.name;
		local allRounds = params.allRounds;
		--local allRoundsScores = params.allRoundsScores;
		
		local stats = {
			rounds              = 0,
			damagePercentage    = 0,
			damageModifier      = 0,
			healingPercentage   = 0,
			healingModifier     = 0,
			wins                = 0,
		};
		
		local rounds = core:GetPlayerRounds({who=name, allRounds=allRounds});
		--local playerScores = core:GetPlayerScores({who:who});
		
		local round;
		local score;
		local roundSize;
		local average;
		for i = 1, table.getn(rounds) do 
			round = rounds[i];
			score = round.scores[name];
			roundSize = core:GetNumKeys(round.scores);
			--core.debug("i: " .. i .. ", roundSize: " .. roundSize .. ", totalDamageDone: " .. round.totalDamageDone .. ", totalHealingDone: " .. round.totalHealingDone);
			
			stats.faction   = stats.faction or score.faction;
			stats.rounds     = stats.rounds + 1;

			
			if (score.damageDone > 0 and round.totalDamageDone > 0) then
				
				stats.damagePercentage = stats.damagePercentage + (score.damageDone / round.totalDamageDone);
				average = round.totalDamageDone / roundSize;
				stats.damageModifier = stats.damageModifier + (score.damageDone / average);
			end

			if (score.healingDone > 0 and round.totalHealingDone > 0) then
				stats.healingPercentage = stats.healingPercentage + (score.healingDone / round.totalHealingDone);
				average = round.totalHealingDone / roundSize;
				stats.healingModifier = stats.healingModifier + (score.healingDone / average);
			end

			if (round.battlefieldWinner == score.faction) then
				stats.wins = stats.wins + 1;
			end
		end

		return stats;
	end

	function RefreshTable( params )
		local scrollTable = params.scrollTable;
		local players = params.players;

		--local allRoundsScores = core:GetRounds();
		local allRounds = params.allRounds or core:GetRounds();
		
		local playerData = {};
		
		local p;
		--local playerNames = {};
		for i = 1, table.getn(players) do 
			p = players[i];
			playerData[ p.name ] = core:GetPlayerBattlefieldStats({name=p.name, allRounds=allRounds});
			--core.echo("p.name: " .. tostring(p.name) .. ", p.faction: " .. tostring(p.faction) .. ", pd.faction: " .. tostring(playerData[ p.name ].faction));
			--playerData[ p.name ].faction = p.faction or playerData[ p.name ].faction;
			if (type(p.faction) == "number" and playerData[ p.name ].faction ~= p.faction) then
				playerData[ p.name ].faction = p.faction;
			end
		end
		
		local displayedData = {};
		
		local wins;
		for name, data in pairs(playerData) do 
		
			if (data.rounds > 0) then
				damagePercentage = data.damagePercentage / data.rounds;
				damageModifier = data.damageModifier / data.rounds;
				
				healingPercentage = data.healingPercentage / data.rounds;
				healingModifier = data.healingModifier / data.rounds;
				
				wins = data.wins / data.rounds;
				
				--core.echo("name: " .. name .. ", faction: " .. data.faction);
				
				table.insert(displayedData, {
					cols = {
						{	-- name
							value = name,
							["color"] = function(faction)
								--core.echo("faction: " .. tostring(faction));
								
								if (faction == 0) then -- horde
									return {r=1.0,g=0.1,b=0.1}
								elseif (faction == 1) then -- ally
										return {r=0,g=0.68,b=0.94}
								else
								--	core.echo(name .. " " .. tostring(faction));
									return {r=0.5,g=0.5,b=0.5}
								end
							end,
							["colorargs"] = {data.faction},
							
						}, 
						
						{	-- Damage Ratio
							value = function (damageModifier)
								return core.Round(damageModifier,2) .. "x";
							end,
							args = {damageModifier},
						},
						
						{	-- Damage Percentage
							value = function (damagePercentage )
								return core.Round(damagePercentage*100).."%";
							end,
							args = {damagePercentage},
						},
						
						{	-- Healing Ratio
							value = function (healingModifier)
								return core.Round(healingModifier,2) .. "x";
							end,
							args = {healingModifier},
						},
						
						{	-- Healing Percentage
							value = function (healingPercentage )
								return core.Round(healingPercentage*100).."%";
							end,
							args = {healingPercentage},
						},
						
						{	-- Wins
							value = function (totalWins, totalRounds, winsPercentage)
								--return totalWins .. "/" .. totalRounds .." (" .. core.Round(winsPercentage*100) .. "%)";
								return core.Round(winsPercentage*100) .. "% (" .. totalWins .. "/" .. totalRounds..")";
							end,
							args = {data.wins, data.rounds, wins},
						},
						
						{	-- Rounds
							value = function (rounds)
								return rounds;
							end,
							args = {data.rounds},
						}
					}
				})
			else
				table.insert(displayedData, {
					cols = {
						{	-- name
							value = name,
							["color"] = function(faction)
								--core.echo("faction: " .. tostring(faction));
								if (faction == 1) then -- ally
									return {r=0,g=0.68,b=0.94}
								elseif (faction == 0) then -- horde
									return {r=1,g=0.1,b=0.1}
								else
								--	core.echo(name .. " " .. tostring(faction));
									return {r=0.5,g=0.5,b=0.5}
								end
							end,
							["colorargs"] = {data.faction},
						}
					}
				});
			end
		end
	
		scrollTable:SetData(displayedData);
		
		return displayedData;
	end

	function core:ShowScores()--	/script _BH:ShowScores()
		local f = AceGUI:Create("Frame")
		f:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)
		f:SetTitle("Battlefield History")
		f:SetStatusText("")
		f:SetLayout("fill")
		
		local window = f.frame;
		
		local tab =  AceGUI:Create("TabGroup")
		tab:SetLayout("Flow")
		-- Setup which tabs to show
		tab:SetTabs({{
			text="Battlefield", 
			value="tab1"
		}, {
		--	text="Alliance", 
		--	value="tab2"
		--}, {
		--	text="Horde", 
		--	value="tab3"
		--}, {
			text="Lifetime", 
			value="tab4"}
		});
		
		tab:SetCallback("OnGroupSelected", onGroupSelected);
		tab:SelectTab("tab1");
		
		f:AddChild(tab);

	end
end

do
	local GetNumBattlefieldScores = GetNumBattlefieldScores;
	local GetBattlefieldScore = GetBattlefieldScore;
	
	function core:GetBattlefieldPlayers( params )
		local players = {};
		
		local name, killingBlows, honorableKills, deaths, honorGained, faction;
		
		for i=1, GetNumBattlefieldScores() do
			name, killingBlows, honorableKills, deaths, honorGained, faction = GetBattlefieldScore(i);
			
			if (string.find(name,"-")) then
				local intEnd = string.find(name, "-");
				name	= string.sub(name, 1, intEnd - 1);
			end
			
			if (not params or not params.faction or params.faction == faction) then
				table.insert(players, {
					name = name,
					faction = faction,
				})
			end
		end
		
		return players;
	end
end

do
	-- Return scores
	function core:GetRounds()
		local rounds = {};
		
		--local rounds = core.db.realm.battlefieldRounds;
		
		local success, round;
		for i = 1, table.getn(core.db.realm.battlefieldRounds) do 
			success, round = core:Deserialize( core.db.realm.battlefieldRounds[i] );
			if (success) then
				--rounds[ score.uuid ] = rounds[ score.uuid ] or {};
				--table.insert(rounds[ score.uuid ], score)
				table.insert(rounds, round)
			end
		end
		
		return rounds;
	end
	
	function core:GetTotalRoundHealing( params )
		local scores = params.scores;
		local total = 0;
		local s;
		for i = 1, table.getn(scores) do 
			s = scores[ i ];
			total = total + s.healingDone;
		end
		
		return total;
	end
	
	function core:GetTotalRoundDamage( params )
		local scores = params.scores;
		local total = 0;
		local s;
		for i = 1, table.getn(scores) do 
			s = scores[ i ];
			total = total + s.damageDone;
		end
		
		return total;
	end
end

do
	local math_floor = math.floor
	
	local zeros
	function core.Round(num, zeros)
		zeros = zeros or 0
		return math_floor( num * 10 ^ zeros + 0.5 ) / 10 ^ zeros
	end
end

do
	

	
	function core:ShowPlayerStats( params )
		local who = params.who;
		
		local f = AceGUI:Create("Frame")
		f:SetCallback("OnClose",function(widget) AceGUI:Release(widget) end)
		f:SetTitle(who)
		f:SetStatusText("")
		f:SetLayout("fill")
		
		local window = f.frame;
		
		local tab =  AceGUI:Create("TabGroup")
		tab:SetLayout("Flow")
		-- Setup which tabs to show
		tab:SetTabs(
			{
				{
				--	text="Rounds", 
				--	value="tab1"
				--}, {
					text="Seen with", 
					value="tab2"
				}
			}
		);
		
		local function onPlayerGroupSelected(container, event, group)
			--core.echo("<onPlayerGroupSelected> group: " .. group);
			container:ReleaseChildren()

			if container.allST then container.allST:Hide() 	end
			if container.battlefieldST then container.battlefieldST:Hide() 	end
			if container.tmST then container.tmST:Hide() 	end

			if group == "tab2" then
				drawTeammatesContainer({
					container=container,
					who=who
				})
			end
		end
		
		tab:SetCallback("OnGroupSelected", onPlayerGroupSelected);
		tab:SelectTab("tab2");
		
		f:AddChild(tab);
	end

	local playerCols = {
		{ name= "Name", width = 100, defaultsort = "dsc", },
		{ name= "Rounds", width = 100, defaultsort = "dsc", },
	}
	
	function drawTeammatesContainer( params )
		local container = params.container;
		local who = params.who;
		
		if not container.tmST then
			local window  = container.frame
			container.tmST = ScrollingTable:CreateST(playerCols, 20, 16, nil, window)
			container.tmST.frame:SetPoint("BOTTOMLEFT",window, 10,10)
			container.tmST.frame:SetPoint("TOP", window, 0, -60)
			container.tmST.frame:SetPoint("RIGHT", window, -10,0)
		end
		container.tmST:Show()
		
		if container.parent then
			local width = 100
			for i, data in pairs(playerCols) do 
				width = width + data.width
			end
			container.parent:SetWidth(width);
		end
		
		--local players = core:GetBattlefieldPlayers();
		
		local teammates = core:GetPlayerTeammates({
			who=who
		});
		
		local displayedData = {};
		
		for name, data in pairs(teammates) do 
			table.insert(displayedData, {
				cols = {
					{
						value = name,
						["color"] = function(faction)
							--core.echo("faction: " .. tostring(faction));
							if (faction == 1) then -- ally
								return {r=0,g=0.68,b=0.94}
							elseif (faction == 0) then -- horde
								return {r=1,g=0.1,b=0.1}
							else
							--	core.echo(name .. " " .. tostring(faction));
								return {r=0.5,g=0.5,b=0.5}
							end
						end,
						["colorargs"] = {data.faction},
					},
					{
						value = data.seen,
					}
				}
			});
		end

		container.tmST:SetData(displayedData);
	end
	
end

function core:GetPlayerRounds(params) 
	local who = params.who;
	local allRounds = params.allRounds or core:GetRounds();

	local rounds = core.db.realm.battlefieldRounds;
	
	local playerRounds = {};
	local success, round;
	for i = 1, table.getn(allRounds) do 
		round = allRounds[i];
		if (round.scores[who]) then
			table.insert(playerRounds, round);
		end
	end
	
	return playerRounds;
end

function core:GetPlayerScores(params) 
	local who = params.who;
	local allRounds = params.allRounds or core:GetRounds();
	
	--local rounds = core.db.realm.battlefieldRounds;
	
	local scores = {};
	local success, round;
	for i = 1, table.getn(allRounds) do 
		round = allRounds[i];
		if (round.scores[who]) then
			table.insert(playerRounds, round.scores[who]);
		end
	end
	
	return scores;
end

function core:GetPlayerTeammates(params)
	local who = params.who;
	--local allRoundsScores = core:GetRounds();

	-- Figure out which rounds the player was in first.
	local playerRounds = core:GetPlayerRounds({who=who});

	-- Count the number of times other players in those rounds were seen.
	local seenCounts = {};
	for i = 1, table.getn(playerRounds) do 
		round = playerRounds[i];
		for name, score in pairs(round.scores) do
			seenCounts[ name ] = seenCounts[ name ] or {seen=0};
			seenCounts[ name ].seen = seenCounts[ name ].seen + 1;
			seenCounts[ name ].faction = score.faction;
		end
	end

	return seenCounts;
end