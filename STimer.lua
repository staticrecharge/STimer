--[[------------------------------------------------------------------------------------------------
Title:					STimer
Author:					Static_Recharge
Version:				3.0.0
Description:		Allows for the creation of a custom countdown timer. The settings menu allows the user to save presets.
------------------------------------------------------------------------------------------------]]--



--[[------------------------------------------------------------------------------------------------
Aliases
------------------------------------------------------------------------------------------------]]--
local EM = EVENT_MANAGER
local CS = CHAT_SYSTEM
local SM = SCENE_MANAGER
local WM = WINDOW_MANAGER



--[[------------------------------------------------------------------------------------------------
Initialization
------------------------------------------------------------------------------------------------]]--

--[[------------------------------------------------------------------------------------------------
ST Class Initialization
ST    - (obj) Parent object containing all functions, tables, variables, constants and timer objects.
------------------------------------------------------------------------------------------------]]--
local ST = ZO_InitializingObject:Subclass()


--[[------------------------------------------------------------------------------------------------
function ST:Initialize()
Inputs:				None
Outputs:			None
Description:	Initializes all of the variables, slash commands and event callbacks. Fired from the creation of the ST class.
------------------------------------------------------------------------------------------------]]--
function ST:Initialize()
  self.addonName = "STimer"
  self.version = "3.0.0"
  self.author = "Static_Recharge"
  self.chatPrefix = "|c9966FF[STimer]: |cFFFFFF"
  self.commandColor = "|c9966FF"
  self.chatSuffix = "|r"
  self.alerted = false
  self.duration = nil
  self.inProgress = false
  self.paused = false
  self.updateInterval = 1 -- seconds
  self.alarmInterval = 0.05 -- seconds
  self.alarmAlpha = 1
  self.alarmAlphaDown = true
  self.alarmAlphaDelta = 0.250
  self.finished = false
  self.Defaults = {
    bgHidden = false,
    x = 0,
    y = 0,
    Presets = {60, 120, 180, 240, 300},
    alarmSound = SOUNDS.NEW_TIMED_NOTIFICATION,
  }

  self.SavedVars = ZO_SavedVars:NewAccountWide("STimerSV", 1, nil, self.Defaults, nil)

  SLASH_COMMANDS["/st"] = function(...) self:CommandParse(...) end

  --[[self.PauseButton = WM:GetControlByName("ST_PanelPauseButton")
  self.PauseButton:SetHandler("onMouseEnter", function(self) ZO_Tooltips_ShowTextTooltip(self, TOP, "Pause/Resume") end)
  self.PauseButton:SetHandler("OnMouseExit", function(self) ZO_Tooltips_HideTextTooltip() end)]]--
  self.Panel = WM:GetControlByName("ST_Panel")
  self.Panel:SetHandler("OnUpdate", function() self:OnUpdate() end)
  self.Panel:SetHandler("OnMoveStop", function() self:OnMoveStop() end)
  self.Duration = WM:GetControlByName("ST_PanelDuration")
  self.BG = WM:GetControlByName("ST_PanelBG")
  self.EditBox = WM:GetControlByName("ST_PanelEditBox")
  self.EditBoxText = WM:GetControlByName("ST_PanelEditBoxText")
  self.EditBoxText:SetHandler("OnEnter", function() self:Stop() self:Start(self.EditBoxText:GetText()) self.EditBox:SetHidden(true) self.Duration:SetHidden(false) end)
  self.EditBoxText:SetHandler("OnEscape", function() self.EditBox:SetHidden(true) self.Duration:SetHidden(false) end)
  self.EditBoxText:SetHandler("OnFocusLost", function() self.EditBox:SetHidden(true) self.Duration:SetHidden(false) end)
  self.Buttons = WM:GetControlByName("ST_PanelButtons")
  self.ButtonMenu = WM:GetControlByName("ST_PanelMenu")
  self.ButtonMenu:SetHandler("OnClicked", function() self:OpenMenu() end)
  self.ButtonsClose = WM:GetControlByName("ST_PanelButtonsClose")
  self.ButtonsClose:SetHandler("OnClicked", function() self:CloseMenu() end)
  self.ButtonsPause = WM:GetControlByName("ST_PanelButtonsPause")
  self.ButtonsPause:SetHandler("OnClicked", function() self:Pause() self:CloseMenu() end)
  self.ButtonsStop = WM:GetControlByName("ST_PanelButtonsStop")
  self.ButtonsStop:SetHandler("OnClicked", function() self:Stop() self:CloseMenu() end)
  self.ButtonsRestart = WM:GetControlByName("ST_PanelButtonsRestart")
  self.ButtonsRestart:SetHandler("OnClicked", function() self:Restart() self:CloseMenu() end)
  self.ButtonsEdit = WM:GetControlByName("ST_PanelButtonsEdit")
  self.ButtonsEdit:SetHandler("OnClicked", function() self.Duration:SetHidden(true) self.EditBox:SetHidden(false) self.EditBoxText:TakeFocus() self:CloseMenu() end)
  self.ButtonsUnlock = WM:GetControlByName("ST_PanelButtonsUnlock")
  self.ButtonsUnlock:SetHandler("OnClicked", function() self.ButtonMenu:SetHidden(not self.ButtonMenu:IsHidden()) end)

  self:RestorePanel()

  -- Scene Manager Callbacks
  local scene = SM:GetScene("hud")
  scene:RegisterCallback("StateChange", function(oldState, newState) self:HUDSceneChange(oldState, newState) end)
  local scene = SM:GetScene("hudui")
  scene:RegisterCallback("StateChange", function(oldState, newState) self:HUDUISceneChange(oldState, newState) end)

  -- Event Registration
  EM:RegisterForEvent(self.addonName, EVENT_PLAYER_ACTIVATED, function(eventCode, initial) self:OnPlayerActivated(eventCode, initial) end)
  EM:RegisterForEvent(self.addonName, EVENT_PLAYER_DEACTIVATED, function(eventCode) self:OnPlayerDeactivated(eventCode) end)
end



--[[------------------------------------------------------------------------------------------------
General Functions
------------------------------------------------------------------------------------------------]]--

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
function ST:CommandParse(args)
Inputs:				args                    - Table of arguments from the command line
Outputs:			None
Description:	Parses the command line input and runs the required functions with appropriate input.
------------------------------------------------------------------------------------------------]]--
function ST:CommandParse(args)
	local Options = {}
	for match in (args .. " "):gmatch("(.-)" .. " ") do
    table.insert(Options, match);
  end

  local command = string.lower(Options[1])
  local param = tonumber(Options[2])

	if command == "" then
		self:SendToChat("Command List",
                  self.commandColor .. "/st start #" .. self.chatSuffix .. " - starts a timer for # minutes.",
                  self.commandColor .. "/st stop" .. self.chatSuffix .. " - stops the current timer.",
                  self.commandColor .. "/st pause" .. self.chatSuffix .. " - toggles pausing and resuming the current timer.",
                  self.commandColor .. "/st hidebg" .. self.chatSuffix .. " - toggles the background visibility of the timer.",
                  self.commandColor .. "/st restart" .. self.chatSuffix .. " - restarts the current timer."
                )
	elseif command == "start" then
    self:Start(tonumber(param))
  elseif command == "stop" then
    self:Stop()
  elseif command == "hidebg" then
    self:HideBG()
  elseif command == "pause" then
    self:Pause()
  elseif command == "restart" then
    self:Restart()
  elseif command == "debug" then
    self:Debug()
  else
    self:SendToChat("Invalid command.")
  end
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



--[[------------------------------------------------------------------------------------------------
Event Callbacks
------------------------------------------------------------------------------------------------]]--

--[[------------------------------------------------------------------------------------------------
function ST:OnMoveStop()
Inputs:				None
Outputs:			None
Description:	Saves the coordinates of the timer window when the user moves it.
------------------------------------------------------------------------------------------------]]--
function ST:OnMoveStop()
  self.SavedVars.x, self.SavedVars.y = self.Panel:GetCenter()
end


--[[------------------------------------------------------------------------------------------------
function ST:OnUpdate()
Inputs:				None
Outputs:			None
Description:	Called on frame update, checks if the timer needs updating.
------------------------------------------------------------------------------------------------]]--
function ST:OnUpdate()
  local now = GetFrameTimeSeconds()
  if self.inProgress then
    if now >= self.nextUpdate then
      self.duration = self.duration - self.updateInterval
      self.nextUpdate = self.nextUpdate + self.updateInterval
      self:UpdateTimer()
    end
  elseif self.finished then
    if now >= self.nextUpdate then
      self.Duration:SetAlpha(self.alarmAlpha)
      if self.alarmAlphaDown then
        self.alarmAlpha = self.alarmAlpha - self.alarmAlphaDelta
        if self.alarmAlpha <= self.alarmAlphaDelta then self.alarmAlphaDown = false end
      else
        self.alarmAlpha = self.alarmAlpha + self.alarmAlphaDelta
        if self.alarmAlpha >= 1 then self.alarmAlphaDown = true end
      end
      self.nextUpdate = now + self.alarmInterval
    end
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:OpenMenu()
Inputs:				None
Outputs:			None
Description:	Called when main panel is clicked.
------------------------------------------------------------------------------------------------]]--
function ST:OpenMenu()
  self.Buttons:SetHidden(false)
end

--[[------------------------------------------------------------------------------------------------
function ST:CloseMenu()
Inputs:				None
Outputs:			None
Description:	Called when main panel is clicked.
------------------------------------------------------------------------------------------------]]--
function ST:CloseMenu()
  self.Buttons:SetHidden(true)
end


--[[------------------------------------------------------------------------------------------------
function ST:OnPlayerActivated(eventCode, initial)
Inputs:				eventCode               - (number) not used.
              initial                 - (bool) true if this is the first load from the character screen.
Outputs:			None
Description:	If this is the initial load it will delete the saved timer info. Otherwise it will load and resume the timer from memory.
------------------------------------------------------------------------------------------------]]--
function ST:OnPlayerActivated(eventCode, initial)
  if initial or (not self.SavedVars.inProgress and not self.SavedVars.paused) then
    self.SavedVars.start = nil
    self.SavedVars.duration = nil
    self.SavedVars.partialUpdate = nil
    self.SavedVars.lastUpdate = nil
    self.SavedVars.inProgress = false
    self.SavedVars.paused = false
  elseif self.SavedVars.inProgress or self.SavedVars.paused then
    local now = GetFrameTimeSeconds()
    local timePassed = now - self.SavedVars.lastUpdate
    local secondsPassed = math.floor(timePassed/self.updateInterval)
    self.start = self.SavedVars.start
    self.partialUpdate = self.SavedVars.partialUpdate
    self.inProgress = self.SavedVars.inProgress
    self.paused = self.SavedVars.paused
    if self.inProgress then
      self.duration = self.SavedVars.duration - secondsPassed
      self.nextUpdate = now + self.SavedVars.partialUpdate
    elseif self.paused then
      self.duration = self.SavedVars.duration
    end
    self:UpdateTimer()
    self:ShowPanel(true)
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:OnPlayerDeactivated()
Inputs:				eventCode               - (number) not used.
Outputs:			None
Description:	If there is a timer running or paused then save it when the character goes through a loading screen.
------------------------------------------------------------------------------------------------]]--
function ST:OnPlayerDeactivated(eventCode)
  if self.inProgress or self.paused then
    local now = GetFrameTimeSeconds()
    self.SavedVars.start = self.start
    self.SavedVars.duration = self.duration
    if not self.paused then
      self.SavedVars.partialUpdate = self.nextUpdate - now
    else
      self.SavedVars.partialUpdate = self.partialUpdate
    end
    self.SavedVars.inProgress = self.inProgress
    self.SavedVars.paused = self.paused
    self.SavedVars.lastUpdate = now
  else
    self.SavedVars.inProgress = false
    self.SavedVars.paused = false
  end
end


--[[------------------------------------------------------------------------------------------------
Main Add-on Registration
------------------------------------------------------------------------------------------------]]--
EM:RegisterForEvent("STimer", EVENT_ADD_ON_LOADED, function(eventCode, addonName)
  if addonName == "STimer" then
    EM:UnregisterForEvent("STimer", EVENT_ADD_ON_LOADED)
    STimer = ST:New()
  end
end)



--[[------------------------------------------------------------------------------------------------
Window Control
------------------------------------------------------------------------------------------------]]--

--[[------------------------------------------------------------------------------------------------
function ST:RestorePanel()
Inputs:				None
Outputs:			None
Description:	Restores the settings of the timer panel from memory.
------------------------------------------------------------------------------------------------]]--
function ST:RestorePanel()
	local x = self.SavedVars.x
	local y = self.SavedVars.y
  local width, height = self.Duration:GetTextDimensions()
  local bgHidden = self.SavedVars.bgHidden
  self.Panel:SetDimensions(width, height)
	if x ~= nil and y ~= nil then
		self.Panel:ClearAnchors()
		self.Panel:SetAnchor(CENTER, GuiRoot, TOPLEFT, x, y)
	end
  self.BG:SetHidden(bgHidden)
end


--[[------------------------------------------------------------------------------------------------
function ST:HideBG()
Inputs:				None
Outputs:			None
Description:	Toggles hidding the background of the timer panel
------------------------------------------------------------------------------------------------]]--
function ST:HideBG()
  self.BG:SetHidden(not self.BG:IsHidden())
  self.SavedVars.bgHidden = self.BG:IsHidden()
end


--[[------------------------------------------------------------------------------------------------
function ST:HUDSceneChange()
Inputs:				oldState                - the previous state of the scene
              newState                - the new state of the scene
Outputs:			None
Description:	Controls hiding or showing the timer panel transitioning to and from the HUD Scene.
------------------------------------------------------------------------------------------------]]--
function ST:HUDSceneChange(oldState, newState)
  if (newState == SCENE_SHOWN) and self.showPanel then
    self.Panel:SetHidden(false)
  elseif (newState == SCENE_HIDDEN) then
    self.Panel:SetHidden(true)
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:HUDUISceneChange()
Inputs:				oldState                - the previous state of the scene
              newState                - the new state of the scene
Outputs:			None
Description:	Controls hiding or showing the timer panel transitioning to and from the HUDUI Scene.
------------------------------------------------------------------------------------------------]]--
function ST:HUDUISceneChange(oldState, newState)
  if (newState == SCENE_SHOWN) and self.showPanel then
    self.Panel:SetHidden(false)
  elseif (newState == SCENE_HIDDEN) then
    self.Panel:SetHidden(true)
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:ShowPanel()
Inputs:				show                    - (bool) true if the panel should be shown
Outputs:			None
Description:	Controls the hidden state of the timer panel.
------------------------------------------------------------------------------------------------]]--
function ST:ShowPanel(show)
  self.showPanel = show
  local sceneName = SM:GetCurrentScene():GetName()
  if show and (sceneName == "hud" or sceneName == "hudui") then
    self.Panel:SetHidden(false)
  else
    self.Panel:SetHidden(true)
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:UpdateTimer()
Inputs:				None
Outputs:			None
Description:	Updates the displayed text on the timer label.
------------------------------------------------------------------------------------------------]]--
function ST:UpdateTimer()
  local value = self.duration
  local hours = math.floor(value/3600)
  local minutes = math.floor(value/60)%60
  local seconds = value%60
  if hours > 0 then
    self.Duration:SetText(string.format("%02i:%02i:%02i", hours, minutes, seconds))
  elseif minutes > 0 then
    self.Duration:SetText(string.format("%02i:%02i", minutes, seconds))
  else
    self.Duration:SetText(string.format("%02i", seconds))
  end
  local width, height = self.Duration:GetTextDimensions()
  self.Panel:SetDimensions(width, height)
  if self.duration <= 0 then
    self:AlarmTimer()
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:AlarmTimer()
Inputs:				None
Outputs:			None
Description:	Flashes the timer when it's finished.
------------------------------------------------------------------------------------------------]]--
function ST:AlarmTimer()
  local now = GetFrameTimeSeconds()
  PlaySound()
  self.duration = 0
  self.inProgress = false
  self.finished = true
  self.alarmAlpha = 1
  self.alarmAlphaDown = true
  self.nextUpdate = now + self.alarmInterval
  self.Duration:SetColor(255, 0, 0, 1)
end



--[[------------------------------------------------------------------------------------------------
Timer Control
------------------------------------------------------------------------------------------------]]--

--[[------------------------------------------------------------------------------------------------
function ST:Start(duration)
Inputs:				duration                - (number) how many minutes to run the timer for (can be a decimal)
Outputs:			None
Description:	Starts the timer with the given duration.
------------------------------------------------------------------------------------------------]]--
function ST:Start(duration)
  if self.inProgress or self.paused then
    self:SendToChat("There is already a timer started. Use " .. self.commandColor .. "/st restart" .. self.chatSuffix .. " to restart the timer.")
  else
    self.start = math.floor(duration * 60)
    self.duration = self.start
    self.nextUpdate = GetFrameTimeSeconds() + self.updateInterval
    self:UpdateTimer()
    self:ShowPanel(true)
    self.inProgress = true
  end
end


--[[------------------------------------------------------------------------------------------------
function ST:Stop()
Inputs:				None
Outputs:			None
Description:	Stops the timer.
------------------------------------------------------------------------------------------------]]--
function ST:Stop()
  self.inProgress = false
  self.paused = false
  self.finished = false
  self.Duration:SetColor(255, 255, 255, 1)
  self:ShowPanel(false)
  --self:SendToChat("Stopped.")
end


--[[------------------------------------------------------------------------------------------------
function ST:Restart()
Inputs:				None
Outputs:			None
Description:	Restarts the current timer.
------------------------------------------------------------------------------------------------]]--
function ST:Restart()
  self:Stop()
  self:Start(self.start/60)
end


--[[------------------------------------------------------------------------------------------------
function ST:Pause()
Inputs:				None
Outputs:			None
Description:	Toggles pausing/resuming the timer.
------------------------------------------------------------------------------------------------]]--
function ST:Pause()
  local now = GetFrameTimeSeconds()
  if self.paused then
    self.nextUpdate = now + self.partialUpdate
    self.inProgress = true
    self.paused = false
  else
    self.partialUpdate = self.nextUpdate - now
    self.inProgress = false
    self.paused = true
  end
end