local SCRIPT_ID = "CandyCornHub_Spectate_System"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local localPlayer = Players.LocalPlayer

local oldGui = localPlayer:WaitForChild("PlayerGui"):FindFirstChild(SCRIPT_ID)
if oldGui then oldGui:Destroy() end

-- Configurations stored per-player
local playerSettings = {} 
local activeESP = {}
local activeLocators = {}
local currentlySpectating = nil
local selectedPlayer = nil

local defaultColor = Color3.fromHSV(0.08, 1, 1)

local function getPlayerSettings(player)
	if not playerSettings[player] then
		playerSettings[player] = {
			Hue = 0.08,
			Sat = 1,
			Value = 1,
			Opacity = 0.75,
			Color = Color3.fromHSV(0.08, 1, 1)
		}
	end
	return playerSettings[player]
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = SCRIPT_ID
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")

-- Helper for dynamic text contrast on the player list
local function applyPlayerListStroke(textLabel, enabled, color)
	local stroke = textLabel:FindFirstChild("TextStrokeStyle")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Name = "TextStrokeStyle"
		stroke.Thickness = 0.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
		stroke.Parent = textLabel
	end
	
	if enabled and color then
		-- Calculate luminance to determine if background is too bright
		local luminance = (0.299 * color.R) + (0.587 * color.G) + (0.114 * color.B)
		if luminance > 0.7 then
			-- Background is bright (like pure white): Use semi-transparent black text
			textLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
			textLabel.TextTransparency = 0.2
			stroke.Color = Color3.fromRGB(255, 255, 255)
			stroke.Transparency = 0.5
		else
			-- Background is dark/colored: Use white text with 0.5 opacity matching color stroke
			textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			textLabel.TextTransparency = 0
			stroke.Color = color
			stroke.Transparency = 0.5
		end
		stroke.Enabled = true
	else
		textLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
		textLabel.TextTransparency = 0
		stroke.Enabled = false
	end
end

local function makeHeaderDraggable(targetFrame, headerLabel)
	local dragging, dragInput, dragStart, startPos
	headerLabel.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = targetFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	headerLabel.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			TweenService:Create(targetFrame, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
			}):Play()
		end
	end)
end

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 180, 0, 180)
MainFrame.Position = UDim2.new(0.05, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Thickness = 1
MainStroke.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 30)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 12
TitleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
TitleLabel.Text = "CANDYCORNHUB"
TitleLabel.Active = true
TitleLabel.Parent = MainFrame
makeHeaderDraggable(MainFrame, TitleLabel)

local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, -20, 1, -40)
ScrollFrame.Position = UDim2.new(0, 10, 0, 35)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.ScrollBarThickness = 4
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
ScrollFrame.Parent = MainFrame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 4)
UIListLayout.Parent = ScrollFrame

UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, UIListLayout.AbsoluteContentSize.Y)
end)

local Dashboard = Instance.new("Frame")
Dashboard.Size = UDim2.new(0, 360, 0, 110)
Dashboard.Position = UDim2.new(0.5, -180, 0.5, -140)
Dashboard.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Dashboard.BorderSizePixel = 0
Dashboard.ClipsDescendants = true
Dashboard.BackgroundTransparency = 1
Dashboard.Visible = false
Dashboard.Active = true
Dashboard.Parent = ScreenGui

local DashCorner = Instance.new("UICorner")
DashCorner.CornerRadius = UDim.new(0, 8)
DashCorner.Parent = Dashboard

local DashStroke = Instance.new("UIStroke")
DashStroke.Color = Color3.fromRGB(255, 255, 255)
DashStroke.Thickness = 1
DashStroke.Parent = Dashboard

local DragHeader = Instance.new("Frame")
DragHeader.Size = UDim2.new(1, 0, 0, 15)
DragHeader.Position = UDim2.new(0, 0, 0, 0)
DragHeader.BackgroundTransparency = 1
DragHeader.Active = true
DragHeader.Parent = Dashboard
makeHeaderDraggable(Dashboard, DragHeader)

local AvatarImage = Instance.new("ImageLabel")
AvatarImage.Size = UDim2.new(0, 60, 0, 60)
AvatarImage.Position = UDim2.new(0, 15, 0, 25)
AvatarImage.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
AvatarImage.Parent = Dashboard

local AvatarCorner = Instance.new("UICorner")
AvatarCorner.CornerRadius = UDim.new(1, 0)
AvatarCorner.Parent = AvatarImage

local DispLabel = Instance.new("TextLabel")
DispLabel.Size = UDim2.new(0, 140, 0, 20)
DispLabel.Position = UDim2.new(0, 85, 0, 18)
DispLabel.BackgroundTransparency = 1
DispLabel.Font = Enum.Font.GothamBold
DispLabel.TextSize = 14
DispLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
DispLabel.TextXAlignment = Enum.TextXAlignment.Left
DispLabel.Parent = Dashboard

local UserLabel = Instance.new("TextLabel")
UserLabel.Size = UDim2.new(0, 140, 0, 15)
UserLabel.Position = UDim2.new(0, 85, 0, 38)
UserLabel.BackgroundTransparency = 1
UserLabel.Font = Enum.Font.Gotham
UserLabel.TextSize = 11
UserLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
UserLabel.TextXAlignment = Enum.TextXAlignment.Left
UserLabel.Parent = Dashboard

local CreatorLabel = Instance.new("TextLabel")
CreatorLabel.Size = UDim2.new(0, 145, 0, 35)
CreatorLabel.Position = UDim2.new(0, 85, 0, 53)
CreatorLabel.BackgroundTransparency = 1
CreatorLabel.Font = Enum.Font.GothamBold
CreatorLabel.TextSize = 11
CreatorLabel.TextXAlignment = Enum.TextXAlignment.Left
CreatorLabel.TextWrapped = true
CreatorLabel.Text = "Creator: Https_Yxvani (Follow me on roblox)"
CreatorLabel.Parent = Dashboard

local function createDashButton(text, pos)
	local Btn = Instance.new("TextButton")
	Btn.Size = UDim2.new(0, 55, 0, 28)
	Btn.Position = pos
	Btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	Btn.Font = Enum.Font.GothamBold
	Btn.TextSize = 10
	Btn.TextColor3 = Color3.fromRGB(220, 220, 220)
	Btn.Text = text
	Btn.Parent = Dashboard

	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 4)
	bc.Parent = Btn

	return Btn
end

local SpectateBtn = createDashButton("VIEW", UDim2.new(1, -125, 0, 22))
local ESPBtn = createDashButton("ESP", UDim2.new(1, -65, 0, 22))
local LocateBtn = createDashButton("LOCATE", UDim2.new(1, -125, 0, 58))
local ColorBtn = createDashButton("COLOR", UDim2.new(1, -65, 0, 58))

local function toggleDashboard(open)
	if open then
		Dashboard.Visible = true
		TweenService:Create(Dashboard, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0}):Play()
	else
		TweenService:Create(Dashboard, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {BackgroundTransparency = 1}):Play()
		task.delay(0.15, function() if not selectedPlayer then Dashboard.Visible = false end end)
	end
end

local ColorPicker = Instance.new("Frame")
ColorPicker.Size = UDim2.new(0, 350, 0, 205)
ColorPicker.Position = UDim2.new(0.5, -175, 0.5, 10)
ColorPicker.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
ColorPicker.BorderSizePixel = 0
ColorPicker.Visible = false
ColorPicker.Active = true
ColorPicker.ClipsDescendants = true
ColorPicker.Parent = ScreenGui

local CPCorner = Instance.new("UICorner")
CPCorner.CornerRadius = UDim.new(0, 8)
CPCorner.Parent = ColorPicker

local CPStroke = Instance.new("UIStroke")
CPStroke.Color = Color3.fromRGB(255, 255, 255)
CPStroke.Thickness = 1
CPStroke.Parent = ColorPicker

local CPTitle = Instance.new("TextLabel")
CPTitle.Size = UDim2.new(1, 0, 0, 25)
CPTitle.BackgroundTransparency = 1
CPTitle.Font = Enum.Font.GothamBold
CPTitle.TextSize = 11
CPTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
CPTitle.Text = "ColorPicker"
CPTitle.Active = true
CPTitle.Parent = ColorPicker
makeHeaderDraggable(ColorPicker, CPTitle)

local CanvasFrame = Instance.new("Frame")
CanvasFrame.Size = UDim2.new(0, 110, 0, 110)
CanvasFrame.Position = UDim2.new(0, 15, 0, 35)
CanvasFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CanvasFrame.BorderSizePixel = 0
CanvasFrame.Active = true
CanvasFrame.Parent = ColorPicker

local CanvasCorner = Instance.new("UICorner")
CanvasCorner.CornerRadius = UDim.new(0, 4)
CanvasCorner.Parent = CanvasFrame

local HueGradient = Instance.new("UIGradient")
HueGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
	ColorSequenceKeypoint.new(0.167, Color3.fromRGB(255, 255, 0)),
	ColorSequenceKeypoint.new(0.333, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 255, 255)),
	ColorSequenceKeypoint.new(0.667, Color3.fromRGB(0, 0, 255)),
	ColorSequenceKeypoint.new(0.833, Color3.fromRGB(255, 0, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0))
})
HueGradient.Parent = CanvasFrame

local SatGradientFrame = Instance.new("Frame")
SatGradientFrame.Size = UDim2.new(1, 0, 1, 0)
SatGradientFrame.BorderSizePixel = 0
SatGradientFrame.Parent = CanvasFrame

local SatGradient = Instance.new("UIGradient")
SatGradient.Rotation = 90
SatGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
})
SatGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(1, 0)
})
SatGradient.Parent = SatGradientFrame

local CanvasPicker = Instance.new("Frame")
CanvasPicker.Size = UDim2.new(0, 8, 0, 8)
CanvasPicker.AnchorPoint = Vector2.new(0.5, 0.5)
CanvasPicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
CanvasPicker.Parent = CanvasFrame

local CPCornerRef = Instance.new("UICorner")
CPCornerRef.CornerRadius = UDim.new(1, 0)
CPCornerRef.Parent = CanvasPicker

local CPStrokeRef = Instance.new("UIStroke")
CPStrokeRef.Color = Color3.fromRGB(0, 0, 0)
CPStrokeRef.Thickness = 1
CPStrokeRef.Parent = CanvasPicker

local SliderFrame = Instance.new("Frame")
SliderFrame.Size = UDim2.new(0, 20, 0, 110)
SliderFrame.Position = UDim2.new(0, 145, 0, 35)
SliderFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderFrame.BorderSizePixel = 0
SliderFrame.Active = true
SliderFrame.Parent = ColorPicker

local SliderCorner = Instance.new("UICorner")
SliderCorner.CornerRadius = UDim.new(0, 4)
SliderCorner.Parent = SliderFrame

local SliderGradient = Instance.new("UIGradient")
SliderGradient.Rotation = 90
SliderGradient.Parent = SliderFrame

local SliderPicker = Instance.new("Frame")
SliderPicker.Size = UDim2.new(1, 4, 0, 6)
SliderPicker.AnchorPoint = Vector2.new(0.5, 0.5)
SliderPicker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
SliderPicker.Parent = SliderFrame

local SPCorner = Instance.new("UICorner")
SPCorner.CornerRadius = UDim.new(0, 2)
SPCorner.Parent = SliderPicker

local SPStroke = Instance.new("UIStroke")
SPStroke.Color = Color3.fromRGB(0, 0, 0)
SPStroke.Thickness = 1
SPStroke.Parent = SliderPicker

local PreviewPanel = Instance.new("Frame")
PreviewPanel.Size = UDim2.new(0, 145, 0, 65)
PreviewPanel.Position = UDim2.new(0, 190, 0, 35)
PreviewPanel.BorderSizePixel = 0
PreviewPanel.Parent = ColorPicker

local PPCorner = Instance.new("UICorner")
PPCorner.CornerRadius = UDim.new(0, 6)
PPCorner.Parent = PreviewPanel

local PPStroke = Instance.new("UIStroke")
PPStroke.Color = Color3.fromRGB(60, 60, 60)
PPStroke.Thickness = 1
PPStroke.Parent = PreviewPanel

local ConfirmBtn = Instance.new("TextButton")
ConfirmBtn.Size = UDim2.new(0, 145, 0, 35)
ConfirmBtn.Position = UDim2.new(0, 190, 0, 110)
ConfirmBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
ConfirmBtn.Font = Enum.Font.GothamBold
ConfirmBtn.TextSize = 11
ConfirmBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ConfirmBtn.Text = "CONFIRM COLOR"
ConfirmBtn.Parent = ColorPicker

local CBCorner = Instance.new("UICorner")
CBCorner.CornerRadius = UDim.new(0, 4)
CBCorner.Parent = ConfirmBtn

local AlphaLabel = Instance.new("TextLabel")
AlphaLabel.Size = UDim2.new(0, 100, 0, 15)
AlphaLabel.Position = UDim2.new(0, 15, 0, 153)
AlphaLabel.BackgroundTransparency = 1
AlphaLabel.Font = Enum.Font.GothamBold
AlphaLabel.TextSize = 9
AlphaLabel.Text = "FILL OPACITY"
AlphaLabel.Parent = ColorPicker

local AlphaTrack = Instance.new("Frame")
AlphaTrack.Size = UDim2.new(0, 320, 0, 10)
AlphaTrack.Position = UDim2.new(0, 15, 0, 173)
AlphaTrack.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
AlphaTrack.BorderSizePixel = 0
AlphaTrack.Active = true
AlphaTrack.Parent = ColorPicker

local ATCorner = Instance.new("UICorner")
ATCorner.CornerRadius = UDim.new(0, 3)
ATCorner.Parent = AlphaTrack

local AlphaFill = Instance.new("Frame")
AlphaFill.BorderSizePixel = 0
AlphaFill.Parent = AlphaTrack

local ATFillCorner = Instance.new("UICorner")
ATFillCorner.CornerRadius = UDim.new(0, 3)
ATFillCorner.Parent = AlphaFill

local AlphaPin = Instance.new("Frame")
AlphaPin.Size = UDim2.new(0, 12, 0, 12)
AlphaPin.AnchorPoint = Vector2.new(0.5, 0.5)
AlphaPin.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
AlphaPin.Parent = AlphaTrack

local APCorner = Instance.new("UICorner")
APCorner.CornerRadius = UDim.new(1, 0)
APCorner.Parent = AlphaPin

local APStroke = Instance.new("UIStroke")
APStroke.Color = Color3.fromRGB(0, 0, 0)
APStroke.Thickness = 1
APStroke.Parent = AlphaPin

local function toggleColorPicker(open)
	if open then
		ColorPicker.Size = UDim2.new(0, 350, 0, 0)
		ColorPicker.Visible = true
		TweenService:Create(ColorPicker, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, 350, 0, 205)
		}):Play()
	else
		local tween = TweenService:Create(ColorPicker, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 350, 0, 0)
		})
		tween:Play()
		tween.Completed:Connect(function()
			if not ColorPicker.Visible then return end
			ColorPicker.Visible = false
		end)
	end
end

local function cleanESP(player)
	if activeESP[player] then activeESP[player]:Destroy() activeESP[player] = nil end
end

local function applyESP(player)
	cleanESP(player)
	if not player.Character then return end
	
	local cfg = getPlayerSettings(player)
	local highlight = Instance.new("Highlight")
	highlight.Name = "CandyESP"
	highlight.FillColor = cfg.Color
	highlight.FillTransparency = 1 - cfg.Opacity
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.OutlineTransparency = 0
	highlight.Adornee = player.Character
	highlight.Parent = ScreenGui
	
	activeESP[player] = highlight
end

local function updateDashboardAndListUI()
	if not selectedPlayer then return end
	local cfg = getPlayerSettings(selectedPlayer)
	
	CreatorLabel.TextColor3 = cfg.Color
	AlphaLabel.TextColor3 = cfg.Color
	ColorBtn.TextColor3 = cfg.Color
	
	SpectateBtn.Text = (currentlySpectating == selectedPlayer) and "UNVIEW" or "VIEW"
	SpectateBtn.TextColor3 = (currentlySpectating == selectedPlayer) and cfg.Color or Color3.fromRGB(220, 220, 220)
	
	ESPBtn.TextColor3 = (activeESP[selectedPlayer] ~= nil) and cfg.Color or Color3.fromRGB(220, 220, 220)
	LocateBtn.TextColor3 = (activeLocators[selectedPlayer] ~= nil) and cfg.Color or Color3.fromRGB(220, 220, 220)
	
	-- Update player list with dynamic contrasts
	for _, target in ipairs(Players:GetPlayers()) do
		local btn = ScrollFrame:FindFirstChild("PlayerBtn_" .. target.Name)
		if btn and btn:IsA("TextButton") then
			local targetCfg = getPlayerSettings(target)
			if activeESP[target] then
				btn.BackgroundColor3 = targetCfg.Color
				applyPlayerListStroke(btn, true, targetCfg.Color)
			else
				btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
				applyPlayerListStroke(btn, false)
			end
		end
	end
end

local function refreshColorPickerDisplay()
	if not selectedPlayer then return end
	local cfg = getPlayerSettings(selectedPlayer)
	
	currentHue = cfg.Hue
	currentSat = cfg.Sat
	currentValue = cfg.Value
	currentOpacity = cfg.Opacity
	
	CanvasPicker.Position = UDim2.new(currentHue, 0, 1 - currentSat, 0)
	SliderPicker.Position = UDim2.new(0.5, 0, 1 - currentValue, 0)
	AlphaPin.Position = UDim2.new(currentOpacity, 0, 0.5, 0)
	AlphaFill.Size = UDim2.new(currentOpacity, 0, 1, 0)
	
	local baseColor = Color3.fromHSV(currentHue, currentSat, 1)
	SliderGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, baseColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
	})
	
	PreviewPanel.BackgroundColor3 = cfg.Color
	PreviewPanel.BackgroundTransparency = 1 - currentOpacity
	AlphaFill.BackgroundColor3 = cfg.Color
end

local function syncColorsFromSliders()
	if not selectedPlayer then return end
	local cfg = getPlayerSettings(selectedPlayer)
	
	cfg.Hue = currentHue
	cfg.Sat = currentSat
	cfg.Value = currentValue
	cfg.Opacity = currentOpacity
	cfg.Color = Color3.fromHSV(currentHue, currentSat, currentValue)
	
	local baseColor = Color3.fromHSV(currentHue, currentSat, 1)
	SliderGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, baseColor),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
	})
	
	PreviewPanel.BackgroundColor3 = cfg.Color
	PreviewPanel.BackgroundTransparency = 1 - currentOpacity
	AlphaFill.BackgroundColor3 = cfg.Color
	AlphaFill.Size = UDim2.new(currentOpacity, 0, 1, 0)
	
	if activeESP[selectedPlayer] then
		applyESP(selectedPlayer)
	end
	
	updateDashboardAndListUI()
end

local function refreshPlayerList()
	for _, child in ipairs(ScrollFrame:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	local index = 0
	for _, target in ipairs(Players:GetPlayers()) do
		if target ~= localPlayer then
			index = index + 1
			local Button = Instance.new("TextButton")
			Button.Name = "PlayerBtn_" .. target.Name
			Button.Size = UDim2.new(1, 0, 0, 26)
			Button.Font = Enum.Font.Gotham
			Button.TextSize = 13 -- Made text slightly bigger as requested
			Button.Text = target.DisplayName or target.Name
			Button.LayoutOrder = index
			Button.Parent = ScrollFrame

			local bCorner = Instance.new("UICorner")
			bCorner.CornerRadius = UDim.new(0, 4)
			bCorner.Parent = Button

			Button.MouseButton1Click:Connect(function()
				if selectedPlayer == target then
					selectedPlayer = nil
					toggleDashboard(false)
					toggleColorPicker(false)
				else
					selectedPlayer = target
					DispLabel.Text = target.DisplayName
					UserLabel.Text = "@" .. target.Name
					AvatarImage.Image = "rbxthumb://type=AvatarHeadShot&id=" .. target.UserId .. "&w=150&h=150"
					
					refreshColorPickerDisplay()
					updateDashboardAndListUI()
					toggleDashboard(true)
				end
			end)
		end
	end
	updateDashboardAndListUI()
end

local pickingCanvas = false
local function updateCanvasPoint(input)
	local framePos = CanvasFrame.AbsolutePosition
	local frameSize = CanvasFrame.AbsoluteSize
	local x = math.clamp((input.Position.X - framePos.X) / frameSize.X, 0, 1)
	local y = math.clamp((input.Position.Y - framePos.Y) / frameSize.Y, 0, 1)
	
	currentHue = x
	currentSat = 1 - y
	CanvasPicker.Position = UDim2.new(x, 0, y, 0)
	syncColorsFromSliders()
end

CanvasFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pickingCanvas = true
		updateCanvasPoint(input)
	end
end)

local pickingSlider = false
local function updateSliderPoint(input)
	local framePos = SliderFrame.AbsolutePosition
	local frameSize = SliderFrame.AbsoluteSize
	local y = math.clamp((input.Position.Y - framePos.Y) / frameSize.Y, 0, 1)
	
	currentValue = 1 - y
	SliderPicker.Position = UDim2.new(0.5, 0, y, 0)
	syncColorsFromSliders()
end

SliderFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pickingSlider = true
		updateSliderPoint(input)
	end
end)

local pickingAlpha = false
local function updateAlphaPoint(input)
	local trackPos = AlphaTrack.AbsolutePosition
	local trackSize = AlphaTrack.AbsoluteSize
	local x = math.clamp((input.Position.X - trackPos.X) / trackSize.X, 0, 1)
	
	currentOpacity = x
	AlphaPin.Position = UDim2.new(x, 0, 0.5, 0)
	syncColorsFromSliders()
end

AlphaTrack.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pickingAlpha = true
		updateAlphaPoint(input)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if pickingCanvas then
			updateCanvasPoint(input)
		elseif pickingSlider then
			updateSliderPoint(input)
		elseif pickingAlpha then
			updateAlphaPoint(input)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		pickingCanvas = false
		pickingSlider = false
		pickingAlpha = false
	end
end)

ConfirmBtn.MouseButton1Click:Connect(function()
	toggleColorPicker(false)
end)

local function cleanLocator(player)
	if activeLocators[player] then activeLocators[player]:Destroy() activeLocators[player] = nil end
end

local function applyLocator(player)
	cleanLocator(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end

	local bb = Instance.new("BillboardGui")
	bb.Name = "CandyLocate"
	bb.Size = UDim2.new(0, 200, 0, 50)
	bb.AlwaysOnTop = true
	bb.ExtentsOffset = Vector3.new(0, 3, 0)
	bb.Adornee = head
	bb.Parent = ScreenGui

	local text = Instance.new("TextLabel")
	text.Size = UDim2.new(1, 0, 1, 0)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.TextSize = 12
	text.TextColor3 = Color3.fromRGB(255, 255, 255)
	text.Parent = bb
	
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Transparency = 0.5
	stroke.Parent = text

	activeLocators[player] = bb
end

local function returnToSelf()
	currentlySpectating = nil
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then camera.CameraSubject = hum end
	updateDashboardAndListUI()
end

local function spectateTarget(player)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then currentlySpectating = player camera.CameraSubject = hum else returnToSelf() end
	updateDashboardAndListUI()
end

SpectateBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	if currentlySpectating == selectedPlayer then returnToSelf() else spectateTarget(selectedPlayer) end
end)

ESPBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	if activeESP[selectedPlayer] then 
		cleanESP(selectedPlayer) 
	else 
		applyESP(selectedPlayer) 
	end
	updateDashboardAndListUI()
end)

LocateBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then return end
	if activeLocators[selectedPlayer] then cleanLocator(selectedPlayer) else applyLocator(selectedPlayer) end
	updateDashboardAndListUI()
end)

ColorBtn.MouseButton1Click:Connect(function()
	toggleColorPicker(not ColorPicker.Visible)
end)

RunService.Heartbeat:Connect(function()
	for player, gui in pairs(activeLocators) do
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
		
		if root and localRoot and gui:FindFirstChild("TextLabel") then
			local dist = math.floor((root.Position - localRoot.Position).Magnitude)
			gui.TextLabel.Text = player.DisplayName .. "\n[" .. dist .. " studs]"
			
			local head = char:FindFirstChild("Head")
			if head and gui.Adornee ~= head then
				gui.Adornee = head
			end
		else
			if not player.Parent then cleanLocator(player) end
		end
	end
	
	-- Respawn-proof persistent view camera handling
	if currentlySpectating then
		if currentlySpectating.Parent then
			local char = currentlySpectating.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				if camera.CameraSubject ~= hum then 
					camera.CameraSubject = hum 
				end
			end
			-- If they are dead/respawning, camera stays locked onto whatever state until new hum is ready
		else
			returnToSelf()
		end
	end
	
	for player, highlight in pairs(activeESP) do
		local char = player.Character
		if char then
			if highlight.Adornee ~= char or highlight.Parent ~= ScreenGui then
				local cfg = getPlayerSettings(player)
				highlight.Adornee = char
				highlight.FillColor = cfg.Color
				highlight.FillTransparency = 1 - cfg.Opacity
				highlight.Parent = ScreenGui
			end
		else
			if not player.Parent then cleanESP(player) end
		end
	end
end)

Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(function(player)
	if currentlySpectating == player then returnToSelf() end
	if selectedPlayer == player then toggleDashboard(false) selectedPlayer = nil toggleColorPicker(false) end
	cleanESP(player)
	cleanLocator(player)
	playerSettings[player] = nil
	refreshPlayerList()
end)

refreshPlayerList()
