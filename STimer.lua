--[[------------------------------------------------------------------------------------------------
Title:					STimer
Author:					Static_Recharge
Version:				3.0.0
Description:		Allows for the creation of a custom countdown timer.
------------------------------------------------------------------------------------------------]]--


--[[----------------------------------------------
Aliases
----------------------------------------------]]--
local EM = EVENT_MANAGER
local CS = CHAT_SYSTEM
local SM = SCENE_MANAGER
local LT = LibTimer
local WM = WINDOW_MANAGER


--[[------------------------------------------------------------------------------------------------
ST Class Initialization
ST    - (obj) Parent object containing all functions, tables, variables, constants and timer objects.
------------------------------------------------------------------------------------------------]]--
local ST = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
function ST:Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, slash commands and event callbacks.
------------------------------------------------------------------------------------------------]]--
function ST:Initialize()
  self.addonName = "STimer"
  self.version = "3.0.0"
  self.author = "Static_Recharge"
  self.chatPrefix = "|c9966FF[STimer]: |cFFFFFF"
  self.chatSuffix = "|r"
  self.alerted = false
  self.secondMode = false
  self.duration = nil
  self.inProgress = false
  self.paused = false
  self.Defaults = {bgHidden = false, left = 0, top = 0}

  self.SavedVars = ZO_SavedVars:NewAccountWide("STimerSV", 1, nil, self.Defaults, nil)

  SLASH_COMMANDS["/st"] = function(...) self:CommandParse(...) end

  --[[self.PauseButton = WM:GetControlByName("ST_PanelPauseButton")
  self.PauseButton:SetHandler("onMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, TOP, "Pause/Resume") end)
  self.PauseButton:SetHandler("OnMouseExit", function(self) ZO_Tooltips_HideTextTooltip() end)]]--
  self.Panel = WM:GetControlByName("ST_Panel")
  self.Panel:SetHandler("OnMoveStop", function() self:OnMoveStop() end)
  self.Label = WM:GetControlByName("ST_PanelLabel")
  self.BG = WM:GetControlByName("ST_PanelBG")

  self:RestorePanel()

  local scene = SM:GetScene("hud")
  scene:RegisterCallback("StateChange", function() self:HUDSceneChange() end)
  local scene = SM:GetScene("hudui")
  scene:RegisterCallback("StateChange", function() self:HUDUISceneChange() end)
end


--[[------------------------------------------------------------------------------------------------
function ST:SendToChat(inputString, ...)
Inputs:				inputString							- (string/number/bool) The input string to be formatted and sent to chat.
							...											- (string/number/bool) More inputs to be placed on new lines within the same message.
Outputs:			None
Description:	Formats text to be sent to the chat box for the user. Bools will be converted to "true" or "false" text formats. All inputs after the first will be placed on a new line within the message. Only the first line gets the library prefix.
------------------------------------------------------------------------------------------------]]--
function ST:SendToChat(inputString, ...)
	if not inputString then return end
	local Args = {...}
	local Output = {}
  if type(inputString) == boolean then
    if inputString then inputString = "true" else inputString = "false" end
  end
	table.insert(Output, self.chatPrefix)
	table.insert(Output, inputString) 
	table.insert(Output, self.chatSuffix)
	if #Args > 0 then
		for i,v in ipairs(Args) do
			if type(v) == boolean then
				if v then v = "true" else v = "false" end
			end
		  table.insert(Output, "\n")
	    table.insert(Output, v) 
	    table.insert(Output, self.chatSuffix)
		end
	end
	CS:AddMessage(table.concat(Output))
end


--[[------------------------------------------------------------------------------------------------
function ST:Debug()
Inputs:				None							
																		
Outputs:			Debugging information
Description:	For testing purposes only
------------------------------------------------------------------------------------------------]]--
function ST:Debug()
  d(LT)
end


function ST:OnMoveStop()
  self.SavedVars.left = self.Panel:GetLeft()
  self.SavedVars.top = self.Panel:GetTop()
end


function ST:RestorePanel()
	local left = self.SavedVars.left
	local top = self.SavedVars.top
  local width, height = self.Label:GetTextDimensions()
  local bgHidden = self.SavedVars.bgHidden
  self.Panel:SetDimensions(width + 18, height + 6)
	if left ~= nil and top ~= nil then
		self.Panel:ClearAnchors()
		self.Panel:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
	end
  self.BG:SetHidden(bgHidden)
end


function ST:HideBG()
  self.BG:SetHidden(not self.BG:IsHidden())
  self.SavedVars.bgHidden = self.BG:IsHidden()
end


function ST:HUDSceneChange(oldState, newState)
  if (newState == SCENE_SHOWN) and (self.inProgress or self.paused) then
    self.Panel:SetHidden(false)
  elseif (newState == SCENE_HIDDEN) then
    self.Panel:SetHidden(true)
  end
end


function ST:HUDUISceneChange(oldState, newState)
  if (newState == SCENE_SHOWN) and (self.inProgress or self.paused) then
    self.Panel:SetHidden(false)
  elseif (newState == SCENE_HIDDEN) then
    self.Panel:SetHidden(true)
  end
end


function ST:ShowPanel()
  local sceneName = SM:GetCurrentScene():GetName()
  if sceneName == "hud" or sceneName == "hudui" then self.Panel:SetHidden(false) else self.Panel:SetHidden(true) end
end


function ST:UpdateTimer(name, value)
  local hours = math.floor(value/3600)
  local minutes = math.floor(value/60)%60
  local seconds = value%60
  self.Label:SetText(string.format("%02i:%02i:%02i", hours, minutes, seconds))
end


function ST:AlarmTimer(name)
  self:SendToChat(name .. " stopped.")
end


--[[----------------------------------------------
Timer Control Functions
----------------------------------------------]]--
function ST:Start(duration)
  self.timerData = {
    name = "STimer-CD",
    timerType = LT_COUNT_DOWN,
    interval = LT_INTERVAL_S,
    start = duration * 60,
    autoPause = true,
    autoResume = true,
    updateCallback = function(name, value) self:UpdateTimer(name, value) end,
    finishedCallback = function(name) self:AlarmTimer(name) end,
  }
  if not LT:IsRegistered(self.timerData.name) then
    LT:RegisterTimer(self.timerData)
  end
  self:UpdateTimer(_, self.timerData.start)
  self:ShowPanel()
  LT:Start(self.timerData.name)
  self.inProgress = LT:IsRunning(self.timerData.name)
end


function ST:Stop()
  LT:Stop(self.timerData.name)
end


function ST:Pause()
  if LT:IsPaused(self.timerData.name) then
    LT:Resume(self.timerData.name)
  elseif LT:IsRunning(self.timerData.name) then
    LT:Pause(self.timerData.name)
  end
end


function ST:BlinkIterator()
  if ST.inProgress then
    ST.Label:SetHidden(not ST.Label:IsHidden())
    zo_callLater(function() ST:BlinkIterator() end, 500)
  end
end


--[[----------------------------------------------
Command Parser
----------------------------------------------]]--
function ST:CommandParse(args)
	local Options = {}
	for match in (args .. " "):gmatch("(.-)" .. " ") do
    table.insert(Options, match);
  end

	if Options[1] == "" then
		ST.SendToChat("Command List\n|cFFFFFF/st start # - starts a timer for # minutes.\n|cFFFFFF/st stop - stops the current timer.\n|cFFFFFF/st pause - toggles pausing and resuming the current timer.\n|cFFFFFF/st hidebg - toggles the background visibility of the timer.")
	elseif Options[1] == "start" then
    self:Start(tonumber(Options[2]))
  elseif Options[1] == "stop" then
    self:Stop()
  elseif Options[1] == "hidebg" then
    self:HideBG()
  elseif Options[1] == "pause" then
    self:Pause()
  elseif Options[1] == "debug" then
    self:Debug()
  else
    self:SendToChat("Invalid command")
  end
end


--[[------------------------------------------------------------------------------------------------
Main add-on event registration.
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent("STimer", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
  if addonName == "STimer" then
    EM:UnregisterForEvent("STimer", EVENT_ADD_ON_LOADED)
    STimer = ST:New()
  end
end)