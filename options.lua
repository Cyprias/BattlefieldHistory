 --[[******************************************************************************
	Addon:      Battlefield History
	Author:     Cyprias
	License:    MIT License	(http://opensource.org/licenses/MIT)
**********************************************************************************]]

local folder, core = ...
local Options = core:NewModule("MainOptions","AceConsole-3.0")
core.defaultSettings.profile = {}

local L = core.L or {};
L.blizOptionsName = "Sorry %s, the options are in another window."
L.title = "Title"
L.version = "Version"
L.notes = "Notes"
L.clickCopy = "Click and Ctrl+C to copy."

do 
	function Options:OnInitialize()
		self:AddBlizzardOptions()
		self:CreateOptionsDisplay()
	end
end

local name = function(info) 
	local key = info[#info]
--~ 	return key
	return L[key.."Name"] and L[key.."Name"]:format(core.db.profile[key]) or key
end
local desc = function(info) 
	local key = info[#info]
--~ 	return key
	return L[key.."Desc"] and L[key.."Desc"]:format(core.db.profile[key]) or key
end

do
	local UnitName = UnitName
	local LibStub = LibStub
	local HideUIPanel = HideUIPanel
	local InterfaceOptionsFrame = InterfaceOptionsFrame
	local GameMenuFrame = GameMenuFrame
	local CreateFrame = CreateFrame
	local wipe = wipe
	
	local coreOpts
	function Options:AddBlizzardOptions()
	-- I'm going to use AceConfigDialog's window to show my options. 
	-- But I still want my addon listed in Blizzard's options frame. 
	-- The only thing shown in the Blizzard options frame will be a button 
	-- to open AceConfigDialog's window.
	
		local blizOptions = {
			name = core.name,
			type = "group",
			args = {
			
				Desc = {
					type = "description",
					name = L.blizOptionsName:format(UnitName("player")),
					order = 1,
				},
				openOptionsFrame = {
					type = "execute",	order	= 2,
					name	= name, --L.openOptionsFrameName,
					desc	= desc, --L.openOptionsFrameDesc,
					func = function(info, v)
						HideUIPanel(InterfaceOptionsFrame)
						HideUIPanel(GameMenuFrame)
						
						--If I open the AceConfigDialog window now it will close once HideUIPanel fires. 
						-- So I'm making a frame to open it on the next frame refresh.
						local f = CreateFrame("Frame")
						f:SetScript("OnUpdate", function(this, elapsed) 
							core:OpenOptionsFrame()
							this:Hide()
							wipe(this)
						end)
					end,
				},
			}
		}
	
		local config = LibStub("AceConfig-3.0")
		local dialog = LibStub("AceConfigDialog-3.0")
		local blizName = core.title.."bliz"
		
		config:RegisterOptionsTable(blizName, blizOptions )
		coreOpts = dialog:AddToBlizOptions(blizName, core.titleFull)
	end
end



do 
	local LibStub = LibStub
	local GENERAL = GENERAL
	local ENABLE = ENABLE
	
	function Options:CreateOptionsDisplay()
		local db = core.db
		local options = {
			type = "group",
			name = core.title,
	--~ 		get = function( k ) return db[k.arg] end,
	--~ 		set = function( k, v ) db[k.arg] = v; end,
			
			get = function(info)
				local key = info[#info]
				return db.profile[key]
			end,
			set = function(info, v)
				local key = info[#info] 
				db.profile[key] = v
				core:Disable()
				core:Enable()
			end,
			
			
			args = {},
			plugins = {},
			disabled = function(info) 
				if info.type == "group" and info[1] == "general" then
					return false
				end
				return not core:IsEnabled()
			end,
		}
		
		options.plugins["profiles"] = { profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(db) }

		options.args.general = {
			type = "group",
			name = GENERAL,
			order = 1,
			args = {
			
				enable = {
					type = "toggle",	order	= 1,
					name	= ENABLE,
					desc	= desc,
					set = function(info,val) 
						if val == true then
							core:Enable()
						else
							core:Disable()
						end
					
					end,
					get = function(info) return core:IsEnabled() end,
					disabled = false,
				},

				showScores = {
					type = "execute",	order	= 4,
					name	= name,
					desc	= desc, 
					func = function(info, v)
						core:ShowScores();
					end,
				},
				
				debugHeader = {
					name	= "Debugging",
					order	= 80,
					type = "header",
				},
				debugMessages = {
					type = "toggle",	order	= 81,
					name	= name,
					desc	= desc,
				},
			},
		}
		
		
		
		local config = LibStub("AceConfig-3.0")
		config:RegisterOptionsTable(core.title, options ) --

		LibStub("AceConfigDialog-3.0"):SetDefaultSize(core.title, 600, 400) --680
		
		self.options = options;
		
		self:BuildAboutMenu()
	end
end

do 
	local tostring = tostring
	local GetAddOnMetadata = GetAddOnMetadata
	local pairs = pairs
	local LibStub = LibStub
	
	function Options:BuildAboutMenu()
		local options = self.options
		
		options.args.about = {
			type = "group",
			name = "About",
			order = 99,
			args = {
			}
		}
		
		local fields = {"Author", "X-Category", "X-License", "X-Email", "Email", "eMail", "X-Website", "X-Credits", "X-Localizations", "X-Donate"}
		local haseditbox = {["X-Website"] = true, ["X-Email"] = true, ["X-Donate"] = true, ["Email"] = true, ["eMail"] = true}
	
		local fNames = {
	--~ 		["Author"] = L.author,
	--~ 		["X-License"] = L.license,
	--~ 		["X-Website"] = L.website,
	--~ 		["X-Donate"] = L.donate,
	--~ 		["X-Email"] = L.email,
		}
		local yellow = "|cffffd100%s|r"

		options.args.about.args.title = {
			type = "description",
			name = yellow:format(L.title..": ")..core.title,
			order = 1,
		}
		options.args.about.args.version = {
			type = "description",
			name = yellow:format(L.version..": ")..core.version,
			order = 2,
		}
		options.args.about.args.notes = {
			type = "description",
			name = yellow:format(L.notes..": ")..tostring(GetAddOnMetadata(folder, "Notes")),
			order = 3,
		}
	
		for i,field in pairs(fields) do
			local val = GetAddOnMetadata(folder, field)
			if val then
				
				if haseditbox[field] then
					options.args.about.args[field] = {
						type = "input",
						name = fNames[field] or field,
						order = i+10,
						desc = L.clickCopy,
						width = "full",
						get = function(info)
							local key = info[#info]
							return GetAddOnMetadata(folder, key)
						end,	
					}
				else
					options.args.about.args[field] = {
						type = "description",
						name = yellow:format((fNames[field] or field)..": ")..val,
						width = "full",
						order = i+10,
					}
				end
		
			end
		end
	
		LibStub("AceConfig-3.0"):RegisterOptionsTable(core.title, options ) --
	end
end
