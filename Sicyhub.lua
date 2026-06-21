print("🍬 Initializing Candyhub UI Drivers...")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local Cam = Workspace.CurrentCamera
local SETTINGS_FILE = "Candyhub_Config.json"

-- Global Runtime State Configuration
local RuntimeState = {
    CurrentTheme = "CottonCandy",
    MenuKeybind = "RightAlt",
    UiTransparency = 0,
    IsListeningForKey = false,
    AutoLoadAcrossServers = true,
    
    -- Features
    ShieldActive = false,
    WalkspeedActive = false, -- Default false
    CurrentSpeed = 16,
    InfiniteJumpActive = false,
    NoclipActive = false,
    FlyActive = false,
    
    -- Combat Core
    AimbotActive = false,
    AutoShootActive = false,
    AimbotTargetPart = "Head",
    AimbotTeamCheck = false,
    WallCheckActive = false,
    PredictionActive = false,
    PredictionValue = 0.15,
    FovRadius = 80,
    ShowFovCircle = true,
    HighlightTarget = true,
    AimbotOriginMode = "Center",
    
    -- ESP & Visuals
    EspActive = false,
    EspTeamCheck = false,
    
    -- Hitbox Toggles
    HitboxActive = false,
    HitboxTeamCheck = true,
    HitboxSize = 2.0,
    HitboxTransparency = 0.7
}

-- Extended Theme Database
local Themes = {
    CottonCandy = { MainBG = Color3.fromRGB(10, 8, 12), Surface = Color3.fromRGB(18, 14, 22), Accent = Color3.fromRGB(255, 105, 180), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(140, 110, 150) },
    SourApple   = { MainBG = Color3.fromRGB(6, 10, 6), Surface = Color3.fromRGB(12, 20, 12), Accent = Color3.fromRGB(50, 205, 50), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(100, 140, 100) },
    Bubblegum   = { MainBG = Color3.fromRGB(12, 8, 10), Surface = Color3.fromRGB(24, 14, 18), Accent = Color3.fromRGB(255, 20, 147), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(160, 100, 120) },
    BlueRaspberry= { MainBG = Color3.fromRGB(6, 8, 14), Surface = Color3.fromRGB(12, 16, 26), Accent = Color3.fromRGB(0, 191, 255), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(90, 120, 160) },
    GrapeSoda   = { MainBG = Color3.fromRGB(8, 6, 12), Surface = Color3.fromRGB(16, 12, 24), Accent = Color3.fromRGB(138, 43, 226), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(120, 90, 150) },
    CherryBomb  = { MainBG = Color3.fromRGB(10, 6, 6), Surface = Color3.fromRGB(20, 12, 12), Accent = Color3.fromRGB(220, 20, 60), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(150, 90, 90) },
    OrangeCream = { MainBG = Color3.fromRGB(12, 8, 6), Surface = Color3.fromRGB(24, 16, 12), Accent = Color3.fromRGB(255, 140, 0), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(160, 110, 90) },
    LemonDrop   = { MainBG = Color3.fromRGB(10, 10, 6), Surface = Color3.fromRGB(20, 20, 12), Accent = Color3.fromRGB(255, 215, 0), Text = Color3.fromRGB(255, 255, 255), Muted = Color3.fromRGB(140, 140, 90) },
    DarkMagic   = { MainBG = Color3.fromRGB(5, 5, 5), Surface = Color3.fromRGB(12, 12, 12), Accent = Color3.fromRGB(150, 50, 220), Text = Color3.fromRGB(230, 230, 230), Muted = Color3.fromRGB(90, 90, 90) }
}

-- Settings IO
local function SaveCurrentSettings()
    pcall(function()
        if writefile then writefile(SETTINGS_FILE, HttpService:JSONEncode(RuntimeState)) end
    end)
end

local function LoadPriorSettings()
    pcall(function()
        if readfile and isfile and isfile(SETTINGS_FILE) then
            local data = HttpService:JSONDecode(readfile(SETTINGS_FILE))
            for k, v in pairs(data) do if RuntimeState[k] ~= nil then RuntimeState[k] = v end end
        end
    end)
end
LoadPriorSettings()

-- Cross-Game Persistence Router
if RuntimeState.AutoLoadAcrossServers and queue_on_teleport then
    player.OnTeleport:Connect(function(State)
        if State == Enum.TeleportState.Started then
            queue_on_teleport([[
                repeat task.wait() until game:IsLoaded()
                pcall(function()
                    loadstring(game:HttpGet("https://raw.githubusercontent.com/YourRepo/Path/main/script.lua"))()
                end)
            ]])
        end
    end)
end

-- Anti-Duplicate Clear
local oldGui = CoreGui:FindFirstChild("CandyhubFramework") or player:WaitForChild("PlayerGui"):FindFirstChild("CandyhubFramework")
if oldGui then oldGui:Destroy() end

local ForceFieldInstance = nil
local FlightVelocity = nil
local FlightGyro = nil
local StoredHitboxData = {}
local ActiveVisualHighlight = nil
local ActiveEspHighlights = {}

-- =============================================================================
-- INTERFACE ASSEMBLY
-- =============================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CandyhubFramework"
ScreenGui.ResetOnSpawn = false
local successParent, _ = pcall(function() ScreenGui.Parent = CoreGui end)
if not successParent then ScreenGui.Parent = player:WaitForChild("PlayerGui") end

local OuterBorder = Instance.new("Frame")
OuterBorder.Size = UDim2.new(0, 312, 0, 522)
OuterBorder.Position = UDim2.new(0.3, 0, 0.2, 0)
OuterBorder.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Accent
OuterBorder.BorderSizePixel = 0
OuterBorder.Active = true
OuterBorder.Draggable = true
OuterBorder.Parent = ScreenGui

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(1, -2, 1, -2)
MainFrame.Position = UDim2.new(0, 1, 0, 1)
MainFrame.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].MainBG
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = OuterBorder

-- DYNAMIC EDGE SIZING HANDLE ENGINE
local SizeHandle = Instance.new("TextButton")
SizeHandle.Size = UDim2.new(0, 14, 0, 14)
SizeHandle.Position = UDim2.new(1, -14, 1, -14)
SizeHandle.BackgroundTransparency = 1
SizeHandle.Text = "◢"
SizeHandle.TextColor3 = Themes[RuntimeState.CurrentTheme].Accent
SizeHandle.TextSize = 14
SizeHandle.Font = Enum.Font.RobotoMono
SizeHandle.ZIndex = 30
SizeHandle.Parent = MainFrame

local isResizing = false
SizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isResizing = true end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then isResizing = false end
end)

UserInputService.InputChanged:Connect(function(input)
    if isResizing and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mousePos = UserInputService:GetMouseLocation()
        local framePos = OuterBorder.AbsolutePosition
        local newWidth = math.clamp(mousePos.X - framePos.X, 280, 800)
        local newHeight = math.clamp(mousePos.Y - framePos.Y, 250, 900)
        OuterBorder.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

-- Protection FOV Canvas Wrap
local FovContainer = Instance.new("Frame")
FovContainer.Size = UDim2.new(1, 0, 1, 0)
FovContainer.BackgroundTransparency = 1
FovContainer.Parent = ScreenGui

local FovCircleFrame = Instance.new("Frame")
FovCircleFrame.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircleFrame.BackgroundTransparency = 1
FovCircleFrame.Visible = RuntimeState.ShowFovCircle
FovCircleFrame.Parent = FovContainer

local FovCorner = Instance.new("UICorner")
FovCorner.CornerRadius = UDim.new(1, 0)
FovCorner.Parent = FovCircleFrame

local FovStroke = Instance.new("UIStroke")
FovStroke.Color = Themes[RuntimeState.CurrentTheme].Accent
FovStroke.Thickness = 1.5
FovStroke.Transparency = 0.4
FovStroke.Parent = FovCircleFrame

-- Notification UI Layer Engine
local NotificationContainer = Instance.new("Frame")
NotificationContainer.Size = UDim2.new(0, 260, 1, 0)
NotificationContainer.Position = UDim2.new(1, 10, 0, 0)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.Parent = ScreenGui

local function TriggerToastAlert(message)
    local alert = Instance.new("Frame")
    alert.Size = UDim2.new(1, -20, 0, 50)
    alert.Position = UDim2.new(1, 0, 0.85, 0)
    alert.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Surface
    alert.BorderSizePixel = 0
    alert.Parent = NotificationContainer

    local sideIndicator = Instance.new("Frame")
    sideIndicator.Size = UDim2.new(0, 4, 1, 0)
    sideIndicator.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Accent
    sideIndicator.BorderSizePixel = 0
    sideIndicator.Parent = alert

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -15, 1, 0)
    txt.Position = UDim2.new(0, 12, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = message
    txt.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
    txt.Font = Enum.Font.RobotoMono
    txt.TextSize = 12
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = alert

    TweenService:Create(NotificationContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(1, -270, 0, 0)}):Play()
    task.wait(3.5)
    TweenService:Create(NotificationContainer, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Position = UDim2.new(1, 10, 0, 0)}):Play()
    task.wait(0.3)
    alert:Destroy()
end

-- Header Strip Setup
local HeaderFrame = Instance.new("Frame")
HeaderFrame.Size = UDim2.new(1, 0, 0, 40)
HeaderFrame.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Surface
HeaderFrame.BorderSizePixel = 0
HeaderFrame.ZIndex = 10
HeaderFrame.Parent = MainFrame

-- Top Left Title Branding Label Placement
local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(0, 160, 1, 0)
HeaderTitle.Position = UDim2.new(0, 15, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Text = "CANDYHUB // CORE"
HeaderTitle.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
HeaderTitle.Font = Enum.Font.RobotoMono
HeaderTitle.TextSize = 14
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Parent = HeaderFrame

local WindowControlsWrap = Instance.new("Frame")
WindowControlsWrap.Size = UDim2.new(0, 40, 1, 0)
WindowControlsWrap.Position = UDim2.new(1, -45, 0, 0)
WindowControlsWrap.BackgroundTransparency = 1
WindowControlsWrap.Parent = HeaderFrame

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(0, 10, 0.5, -12)
MinimizeBtn.BackgroundTransparency = 1
MinimizeBtn.Text = "—"
MinimizeBtn.TextColor3 = Themes[RuntimeState.CurrentTheme].Muted
MinimizeBtn.Font = Enum.Font.RobotoMono
MinimizeBtn.TextSize = 13
MinimizeBtn.Parent = WindowControlsWrap

MinimizeBtn.MouseEnter:Connect(function() MinimizeBtn.TextColor3 = Themes[RuntimeState.CurrentTheme].Accent end)
MinimizeBtn.MouseLeave:Connect(function() MinimizeBtn.TextColor3 = Themes[RuntimeState.CurrentTheme].Muted end)

MinimizeBtn.MouseButton1Click:Connect(function()
    OuterBorder.Visible = false
    FovContainer.Visible = false
    task.spawn(function()
        TriggerToastAlert("Interface Hidden. Use Key [" .. string.upper(RuntimeState.MenuKeybind) .. "] to reopen.")
    end)
end)

-- =============================================================================
-- ✨ HORIZONTAL SCROLLABLE TAB NAV DECK ENGINE
-- =============================================================================
local TabNavigationStrip = Instance.new("ScrollingFrame")
TabNavigationStrip.Size = UDim2.new(1, 0, 0, 36)
TabNavigationStrip.Position = UDim2.new(0, 0, 0, 40)
TabNavigationStrip.BackgroundColor3 = Color3.fromRGB(16, 12, 16)
TabNavigationStrip.BackgroundTransparency = 0
TabNavigationStrip.BorderSizePixel = 0
TabNavigationStrip.ScrollBarThickness = 3
TabNavigationStrip.ScrollBarImageColor3 = Themes[RuntimeState.CurrentTheme].Accent
TabNavigationStrip.ScrollingDirection = Enum.ScrollingDirection.X
TabNavigationStrip.ZIndex = 100 
TabNavigationStrip.Parent = MainFrame

local TabStripLayout = Instance.new("UIListLayout")
TabStripLayout.FillDirection = Enum.FillDirection.Horizontal
TabStripLayout.SortOrder = Enum.SortOrder.LayoutOrder
TabStripLayout.Padding = UDim.new(0, 4)
TabStripLayout.Parent = TabNavigationStrip

local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingLeft = UDim.new(0, 6)
TabPadding.PaddingRight = UDim.new(0, 6)
TabPadding.PaddingTop = UDim.new(0, 4)
TabPadding.PaddingBottom = UDim.new(0, 4)
TabPadding.Parent = TabNavigationStrip

-- Content Canvas Area Frame
local ContentCanvas = Instance.new("Frame")
ContentCanvas.Size = UDim2.new(1, 0, 1, -76)
ContentCanvas.Position = UDim2.new(0, 0, 0, 76)
ContentCanvas.BackgroundTransparency = 1
ContentCanvas.ClipsDescendants = true
ContentCanvas.Parent = MainFrame

local TabRegistry = {}
local ActiveTabName = ""

local function OpenTargetTabContainer(tabName)
    for name, tabObj in pairs(TabRegistry) do
        if name == tabName then
            tabObj.Pane.Visible = true
            tabObj.Button.TextColor3 = Themes[RuntimeState.CurrentTheme].Accent
            tabObj.Button.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Surface
            tabObj.Outline.Color = Themes[RuntimeState.CurrentTheme].Accent
        else
            tabObj.Pane.Visible = false
            tabObj.Button.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
            tabObj.Button.BackgroundColor3 = Color3.fromRGB(24, 20, 24)
            tabObj.Outline.Color = Color3.fromRGB(45, 40, 45)
        end
    end
    ActiveTabName = tabName
end

local function RegisterNewNavigationTab(tabName, orderId)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 80, 1, 0)
    button.BackgroundColor3 = Color3.fromRGB(24, 20, 24)
    button.BorderSizePixel = 0
    button.Text = string.upper(tabName)
    button.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
    button.Font = Enum.Font.RobotoMono
    button.TextSize = 11
    button.LayoutOrder = orderId
    button.ZIndex = 105 
    button.Parent = TabNavigationStrip

    local tabStroke = Instance.new("UIStroke")
    tabStroke.Thickness = 1
    tabStroke.Color = Color3.fromRGB(45, 40, 45)
    tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    tabStroke.Parent = button

    local pane = Instance.new("ScrollingFrame")
    pane.Size = UDim2.new(1, -20, 1, -10)
    pane.Position = UDim2.new(0, 10, 0, 5)
    pane.BackgroundTransparency = 1
    pane.BorderSizePixel = 0
    pane.ScrollBarThickness = 3
    pane.ScrollBarImageColor3 = Themes[RuntimeState.CurrentTheme].Accent
    pane.Visible = false
    pane.Parent = ContentCanvas

    local layout = Instance.new("UIListLayout")
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = pane

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        pane.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end)

    button.MouseButton1Click:Connect(function()
        OpenTargetTabContainer(tabName)
    end)

    TabRegistry[tabName] = { Button = button, Pane = pane, Layout = layout, Outline = tabStroke }
end

-- Register Subsystems
RegisterNewNavigationTab("Main", 1)
RegisterNewNavigationTab("Combat", 2)
RegisterNewNavigationTab("Hitboxes", 3)
RegisterNewNavigationTab("Settings", 4)

local function RecomputeTabContainerCanvas()
    local combinedWidth = 0
    for _, item in ipairs(TabNavigationStrip:GetChildren()) do
        if item:IsA("TextButton") then
            combinedWidth = combinedWidth + item.Size.X.Offset + TabStripLayout.Padding.Offset
        end
    end
    TabNavigationStrip.CanvasSize = UDim2.new(0, combinedWidth + 20, 0, 0)
end
task.spawn(RecomputeTabContainerCanvas)
TabStripLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(RecomputeTabContainerCanvas)

-- =============================================================================
-- CONTROLS ENGINE FACTORIES
-- =============================================================================
local function CreateSectionHeader(tabName, text, order)
    local targetPane = TabRegistry[tabName].Pane
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -4, 0, 22)
    container.BackgroundTransparency = 1
    container.LayoutOrder = order
    container.Parent = targetPane

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.upper(">> " .. text)
    label.TextColor3 = Themes[RuntimeState.CurrentTheme].Muted
    label.Font = Enum.Font.RobotoMono
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
end

local function CreateFunctionalToggle(tabName, text, configKey, order, callback)
    local targetPane = TabRegistry[tabName].Pane
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -4, 0, 36)
    container.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Surface
    container.BorderSizePixel = 0
    container.LayoutOrder = order
    container.Parent = targetPane

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 12)
    title.BackgroundTransparency = 1
    title.Text = text
    title.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
    title.Font = Enum.Font.RobotoMono
    title.TextSize = 12
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = container

    local checkbox = Instance.new("TextButton")
    checkbox.Size = UDim2.new(0, 36, 0, 18)
    checkbox.Position = UDim2.new(1, -48, 0.5, -9)
    checkbox.BackgroundColor3 = RuntimeState[configKey] and Themes[RuntimeState.CurrentTheme].Accent or Color3.fromRGB(30, 30, 35)
    checkbox.BorderSizePixel = 0
    checkbox.Text = ""
    checkbox.Parent = container

    local checkboxOutline = Instance.new("UIStroke")
    checkboxOutline.Thickness = 1
    checkboxOutline.Color = Color3.fromRGB(60, 55, 65)
    checkboxOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    checkboxOutline.Parent = checkbox

    local innerIndicator = Instance.new("Frame")
    innerIndicator.Size = UDim2.new(0, 12, 0, 12)
    innerIndicator.Position = RuntimeState[configKey] and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
    innerIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    innerIndicator.BorderSizePixel = 0
    innerIndicator.Parent = checkbox

    checkbox.MouseButton1Click:Connect(function()
        RuntimeState[configKey] = not RuntimeState[configKey]
        SaveCurrentSettings()
        local active = RuntimeState[configKey]
        checkbox.BackgroundColor3 = active and Themes[RuntimeState.CurrentTheme].Accent or Color3.fromRGB(30, 30, 35)
        innerIndicator.Position = active and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
        if callback then callback(active) end
    end)
end

local function CreateValueSlider(tabName, text, configKey, min, max, isFloat, order, callback)
    local targetPane = TabRegistry[tabName].Pane
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -4, 0, 48)
    container.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Surface
    container.BorderSizePixel = 0
    container.LayoutOrder = order
    container.Parent = targetPane

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -80, 0, 22)
    label.Position = UDim2.new(0, 12, 0, 2)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
    label.Font = Enum.Font.RobotoMono
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local valInput = Instance.new("TextBox")
    valInput.Size = UDim2.new(0, 50, 0, 16)
    valInput.Position = UDim2.new(1, -62, 0, 4)
    valInput.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
    valInput.BorderSizePixel = 0
    valInput.Text = tostring(RuntimeState[configKey])
    valInput.TextColor3 = Themes[RuntimeState.CurrentTheme].Accent
    valInput.Font = Enum.Font.RobotoMono
    valInput.TextSize = 11
    valInput.ClearTextOnFocus = false
    valInput.Parent = container

    local valOutline = Instance.new("UIStroke")
    valOutline.Thickness = 1
    valOutline.Color = Color3.fromRGB(60, 55, 65)
    valOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    valOutline.Parent = valInput

    local slideTrack = Instance.new("Frame")
    slideTrack.Size = UDim2.new(1, -24, 0, 4)
    slideTrack.Position = UDim2.new(0, 12, 0, 34)
    slideTrack.BackgroundColor3 = Color3.fromRGB(35, 35, 42)
    slideTrack.BorderSizePixel = 0
    slideTrack.Parent = container

    local slideFill = Instance.new("Frame")
    local initialPct = math.clamp((RuntimeState[configKey] - min) / (max - min), 0, 1)
    slideFill.Size = UDim2.new(initialPct, 0, 1, 0)
    slideFill.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Accent
    slideFill.BorderSizePixel = 0
    slideFill.Parent = slideTrack

    local slideNode = Instance.new("TextButton")
    slideNode.Size = UDim2.new(0, 6, 0, 10)
    slideNode.Position = UDim2.new(initialPct, -3, 0.5, -5)
    slideNode.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Text
    slideNode.BorderSizePixel = 0
    slideNode.Text = ""
    slideNode.Parent = slideTrack

    local dragging = false
    local function updateFromPosition(inputX)
        local pct = math.clamp((inputX - slideTrack.AbsolutePosition.X) / slideTrack.AbsoluteSize.X, 0, 1)
        local rawValue = min + (pct * (max - min))
        local finalVal = isFloat and (math.floor(rawValue * 100) / 100) or math.round(rawValue)
        
        RuntimeState[configKey] = finalVal
        SaveCurrentSettings()
        valInput.Text = tostring(finalVal)
        slideFill.Size = UDim2.new(pct, 0, 1, 0)
        slideNode.Position = UDim2.new(pct, -3, 0.5, -5)
        if callback then callback(finalVal) end
    end

    slideNode.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromPosition(input.Position.X)
        end
    end)

    valInput.FocusLost:Connect(function()
        local n = tonumber(valInput.Text)
        if n then
            local clamped = math.clamp(n, min, max)
            local finalVal = isFloat and (math.floor(clamped * 100) / 100) or math.round(clamped)
            RuntimeState[configKey] = finalVal
            SaveCurrentSettings()
            valInput.Text = tostring(finalVal)
            local pct = (finalVal - min) / (max - min)
            slideFill.Size = UDim2.new(pct, 0, 1, 0)
            slideNode.Position = UDim2.new(pct, -3, 0.5, -5)
            if callback then callback(finalVal) end
        else
            valInput.Text = tostring(RuntimeState[configKey])
        end
    end)
end

local function CreateFunctionalDropdown(tabName, text, configKey, optionsList, order, callback)
    local targetPane = TabRegistry[tabName].Pane
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -4, 0, 36)
    container.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Surface
    container.BorderSizePixel = 0
    container.LayoutOrder = order
    container.Parent = targetPane

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 120, 1, 0)
    label.Position = UDim2.new(0, 12)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
    label.Font = Enum.Font.RobotoMono
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(1, -140, 0, 22)
    dropBtn.Position = UDim2.new(1, -130, 0.5, -11)
    dropBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    dropBtn.BorderSizePixel = 0
    dropBtn.Text = string.upper(tostring(RuntimeState[configKey])) .. " ▼"
    dropBtn.TextColor3 = Themes[RuntimeState.CurrentTheme].Accent
    dropBtn.Font = Enum.Font.RobotoMono
    dropBtn.TextSize = 10
    dropBtn.Parent = container

    local dropOutline = Instance.new("UIStroke")
    dropOutline.Thickness = 1
    dropOutline.Color = Color3.fromRGB(60, 55, 65)
    dropOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    dropOutline.Parent = dropBtn

    local listHolder = Instance.new("Frame")
    listHolder.Size = UDim2.new(1, 0, 0, #optionsList * 22)
    listHolder.Position = UDim2.new(0, 0, 1, 2)
    listHolder.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
    listHolder.BorderSizePixel = 0
    listHolder.Visible = false
    listHolder.ZIndex = 50
    listHolder.Parent = dropBtn

    local stroke = Instance.new("UIStroke")
    stroke.Color = Themes[RuntimeState.CurrentTheme].Accent
    stroke.Thickness = 1
    stroke.Parent = listHolder

    for i, opt in ipairs(optionsList) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 22)
        optBtn.Position = UDim2.new(0, 0, 0, (i - 1) * 22)
        optBtn.BackgroundColor3 = Color3.fromRGB(24, 24, 28)
        optBtn.BorderSizePixel = 0
        optBtn.Text = string.upper(tostring(opt))
        optBtn.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
        optBtn.Font = Enum.Font.RobotoMono
        optBtn.TextSize = 10
        optBtn.ZIndex = 51
        optBtn.Parent = listHolder

        optBtn.MouseButton1Click:Connect(function()
            RuntimeState[configKey] = opt
            SaveCurrentSettings()
            dropBtn.Text = string.upper(tostring(opt)) .. " ▼"
            listHolder.Visible = false
            if callback then callback(opt) end
        end)
    end

    dropBtn.MouseButton1Click:Connect(function() listHolder.Visible = not listHolder.Visible end)
end

-- =============================================================================
-- MECHANICAL LOGIC ROUTER HOOKS
-- =============================================================================
local function CheckWallObstruction(targetPart)
    if not RuntimeState.WallCheckActive then return true end
    local origin = Cam.CFrame.Position
    local direction = (targetPart.Position - origin).Unit * (targetPart.Position - origin).Magnitude
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {player.Character, Cam}
    
    local result = Workspace:Raycast(origin, direction, raycastParams)
    if result and result.Instance:IsDescendantOf(targetPart.Parent) then return true end
    return false
end

local function CleanActiveHighlight()
    if ActiveVisualHighlight then ActiveVisualHighlight:Destroy() ActiveVisualHighlight = nil end
end

local function CleanGlobalEsp()
    for char, hl in pairs(ActiveEspHighlights) do if hl then hl:Destroy() end end
    table.clear(ActiveEspHighlights)
end

local function ProcessGlobalEspEngine()
    if not RuntimeState.EspActive then CleanGlobalEsp() return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            local isEnemy = not (RuntimeState.EspTeamCheck and plr.Team == player.Team)
            local char = plr.Character
            if isEnemy then
                if not ActiveEspHighlights[char] then
                    local hl = Instance.new("Highlight")
                    hl.FillColor = Themes[RuntimeState.CurrentTheme].Accent
                    hl.FillTransparency = 0.5
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = char
                    ActiveEspHighlights[char] = hl
                end
            else
                if ActiveEspHighlights[char] then ActiveEspHighlights[char]:Destroy() ActiveEspHighlights[char] = nil end
            end
        end
    end
end

local function UpdatePlayerLockHighlight(targetCharacter)
    if not RuntimeState.HighlightTarget or not targetCharacter then CleanActiveHighlight() return end
    if not ActiveVisualHighlight or ActiveVisualHighlight.Parent ~= targetCharacter then
        CleanActiveHighlight()
        local hl = Instance.new("Highlight")
        hl.FillColor = Color3.fromRGB(255, 255, 255)
        hl.FillTransparency = 0.7
        hl.OutlineColor = Themes[RuntimeState.CurrentTheme].Accent
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = targetCharacter
        ActiveVisualHighlight = hl
    end
end

local function ResetPlayerHitboxes()
    for plr, data in pairs(StoredHitboxData) do
        if plr and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.Size = data.Size hrp.Transparency = data.Transparency hrp.Color = data.Color hrp.CanCollide = data.CanCollide
            end
        end
    end
    table.clear(StoredHitboxData)
end

local function ProcessHitboxCalculations()
    if not RuntimeState.HitboxActive then return end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp:IsA("BasePart") then
                local isEnemy = not (RuntimeState.HitboxTeamCheck and plr.Team == player.Team)
                if isEnemy then
                    if not StoredHitboxData[plr] then
                        StoredHitboxData[plr] = { Size = hrp.Size, Transparency = hrp.Transparency, Color = hrp.Color, CanCollide = hrp.CanCollide }
                    end
                    hrp.Size = Vector3.new(RuntimeState.HitboxSize, RuntimeState.HitboxSize, RuntimeState.HitboxSize)
                    hrp.Transparency = RuntimeState.HitboxTransparency
                    hrp.Color = Themes[RuntimeState.CurrentTheme].Accent
                    hrp.CanCollide = false
                end
            end
        end
    end
end

local function FetchOptimalAimbotVector()
    local targetPlr = nil
    local minDistance = math.huge
    local baseOrigin = Cam.ViewportSize / 2
    if RuntimeState.AimbotOriginMode == "Cursor" then baseOrigin = UserInputService:GetMouseLocation() end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= player and plr.Character then
            if RuntimeState.AimbotTeamCheck and plr.Team == player.Team then continue end
            local part = plr.Character:FindFirstChild(RuntimeState.AimbotTargetPart)
            if part then
                local sPos, onScreen = Cam:WorldToViewportPoint(part.Position)
                local screenDist = (Vector2.new(sPos.X, sPos.Y) - baseOrigin).Magnitude
                if onScreen and screenDist < minDistance and screenDist < RuntimeState.FovRadius then
                    if CheckWallObstruction(part) then minDistance = screenDist targetPlr = plr end
                end
            end
        end
    end
    return targetPlr
end

-- =============================================================================
-- POPULATE SECTIONS
-- =============================================================================

-- TAB: MAIN (MOVEMENT)
CreateSectionHeader("Main", "Advanced Movement Drivers", 1)
CreateFunctionalToggle("Main", "Forcefield Shield Barrier", "ShieldActive", 2, function(active)
    if player.Character then
        if active then ForceFieldInstance = Instance.new("ForceField") ForceFieldInstance.Parent = player.Character
        elseif ForceFieldInstance then ForceFieldInstance:Destroy() end
    end
end)
CreateFunctionalToggle("Main", "Override Walkspeed Engine", "WalkspeedActive", 3)
CreateValueSlider("Main", "Engine Velocity Scale", "CurrentSpeed", 16, 250, false, 4)
CreateFunctionalToggle("Main", "Infinite Jump Anchor", "InfiniteJumpActive", 5)
CreateFunctionalToggle("Main", "Phase Shift Noclip", "NoclipActive", 6)
CreateFunctionalToggle("Main", "Aero Flight Core Engine", "FlyActive", 7, function(active)
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if active then
        FlightVelocity = Instance.new("BodyVelocity") FlightVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge) FlightVelocity.Velocity = Vector3.new(0,0,0) FlightVelocity.Parent = root
        FlightGyro = Instance.new("BodyGyro") FlightGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge) FlightGyro.CFrame = root.CFrame FlightGyro.Parent = root
    else
        if FlightVelocity then FlightVelocity:Destroy() FlightVelocity = nil end
        if FlightGyro then FlightGyro:Destroy() FlightGyro = nil end
    end
end)

-- TAB: COMBAT
CreateSectionHeader("Combat", "Lock Settings Engine", 1)
CreateFunctionalToggle("Combat", "Targeting Lock Engine", "AimbotActive", 2)
CreateFunctionalToggle("Combat", "Auto Shoot Engine", "AutoShootActive", 3)
CreateFunctionalDropdown("Combat", "Acquisition Object Part", "AimbotTargetPart", {"Head", "Torso", "HumanoidRootPart"}, 4)
CreateFunctionalDropdown("Combat", "Lock Origin Vector", "AimbotOriginMode", {"Center", "Cursor"}, 5)
CreateFunctionalToggle("Combat", "Raycast Wall Check", "WallCheckActive", 6)
CreateFunctionalToggle("Combat", "Exclude Team Nodes", "AimbotTeamCheck", 7)

CreateSectionHeader("Combat", "Universal Visual Arrays", 8)
CreateFunctionalToggle("Combat", "Global ESP Highlight", "EspActive", 9, function(act) if not act then CleanGlobalEsp() end end)
CreateFunctionalToggle("Combat", "Filter Allied ESP Profiles", "EspTeamCheck", 10, function() CleanGlobalEsp() end)
CreateFunctionalToggle("Combat", "Render Target Lock Trace", "HighlightTarget", 11, function(act) if not act then CleanActiveHighlight() end end)
CreateFunctionalToggle("Combat", "Render FOV Vector Circle", "ShowFovCircle", 12, function(act) FovCircleFrame.Visible = act end)
CreateValueSlider("Combat", "Acquisition Window FOV", "FovRadius", 10, 600, false, 13)
CreateFunctionalToggle("Combat", "Vector Latency Predict", "PredictionActive", 14)
CreateValueSlider("Combat", "Latency Constant Value", "PredictionValue", 0.01, 0.99, true, 15)

-- TAB: HITBOXES
CreateSectionHeader("Hitboxes", "Hitbox Dilation Arrays", 1)
CreateFunctionalToggle("Hitboxes", "Hitbox Extender Core", "HitboxActive", 2, function(active) if not active then ResetPlayerHitboxes() else ProcessHitboxCalculations() end end)
CreateFunctionalToggle("Hitboxes", "Filter Allied Hitboxes", "HitboxTeamCheck", 3, function() if RuntimeState.HitboxActive then ResetPlayerHitboxes() ProcessHitboxCalculations() end end)
CreateValueSlider("Hitboxes", "Hull Geometry Multiplier", "HitboxSize", 2, 40, false, 4, function() ProcessHitboxCalculations() end)
CreateValueSlider("Hitboxes", "Hull Raycast Opacity", "HitboxTransparency", 0.1, 0.9, true, 5, function() ProcessHitboxCalculations() end)

-- TAB: SETTINGS
CreateSectionHeader("Settings", "Framework Customization", 1)
CreateFunctionalToggle("Settings", "Auto-Load Across Servers", "AutoLoadAcrossServers", 2)

local KeybindContainer = Instance.new("Frame")
KeybindContainer.Size = UDim2.new(1, -4, 0, 36)
KeybindContainer.BackgroundColor3 = Themes[RuntimeState.CurrentTheme].Surface
KeybindContainer.BorderSizePixel = 0
KeybindContainer.LayoutOrder = 3
KeybindContainer.Parent = TabRegistry["Settings"].Pane

local KeybindLabel = Instance.new("TextLabel")
KeybindLabel.Size = UDim2.new(0, 120, 1, 0)
KeybindLabel.Position = UDim2.new(0, 12)
KeybindLabel.BackgroundTransparency = 1
KeybindLabel.Text = "Interface Menu Toggle"
KeybindLabel.TextColor3 = Themes[RuntimeState.CurrentTheme].Text
KeybindLabel.Font = Enum.Font.RobotoMono
KeybindLabel.TextSize = 11
KeybindLabel.TextXAlignment = Enum.TextXAlignment.Left
KeybindLabel.Parent = KeybindContainer

local KeybindCaptureBtn = Instance.new("TextButton")
KeybindCaptureBtn.Size = UDim2.new(1, -140, 0, 22)
KeybindCaptureBtn.Position = UDim2.new(1, -130, 0.5, -11)
KeybindCaptureBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
KeybindCaptureBtn.BorderSizePixel = 0
KeybindCaptureBtn.Text = string.upper(RuntimeState.MenuKeybind)
KeybindCaptureBtn.TextColor3 = Themes[RuntimeState.CurrentTheme].Accent
KeybindCaptureBtn.Font = Enum.Font.RobotoMono
KeybindCaptureBtn.TextSize = 10
KeybindCaptureBtn.Parent = KeybindContainer

local kbOutline = Instance.new("UIStroke")
kbOutline.Thickness = 1
kbOutline.Color = Color3.fromRGB(60, 55, 65)
kbOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
kbOutline.Parent = KeybindCaptureBtn

KeybindCaptureBtn.MouseButton1Click:Connect(function()
    RuntimeState.IsListeningForKey = true
    KeybindCaptureBtn.Text = "PRESS ANY KEY..."
    KeybindCaptureBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
end)

UserInputService.InputBegan:Connect(function(input)
    if RuntimeState.IsListeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Escape then
            RuntimeState.MenuKeybind = input.KeyCode.Name
            SaveCurrentSettings()
            RuntimeState.IsListeningForKey = false
            KeybindCaptureBtn.Text = string.upper(input.KeyCode.Name)
            KeybindCaptureBtn.TextColor3 = Themes[RuntimeState.CurrentTheme].Accent
        end
    else
        if input.KeyCode.Name == RuntimeState.MenuKeybind then
            OuterBorder.Visible = not OuterBorder.Visible
            FovContainer.Visible = OuterBorder.Visible
        end
    end
end)

local function ApplyTransparencyModifier(value)
    local t = value / 100
    MainFrame.BackgroundTransparency = t
    HeaderFrame.BackgroundTransparency = t
    TabNavigationStrip.BackgroundTransparency = t
    for _, tab in pairs(TabRegistry) do
        for _, object in ipairs(tab.Pane:GetChildren()) do
            if object:IsA("Frame") then
                object.BackgroundTransparency = t
                for _, inner in ipairs(object:GetChildren()) do
                    if inner:IsA("TextBox") or inner:IsA("TextButton") then
                        inner.BackgroundTransparency = math.clamp(t, 0, 0.4)
                    end
                end
            end
        end
    end
end

CreateValueSlider("Settings", "Layer Surface Opacity", "UiTransparency", 0, 80, false, 4, function(val)
    ApplyTransparencyModifier(val)
end)

CreateFunctionalDropdown("Settings", "Active Theme Palette", "CurrentTheme", {"CottonCandy", "SourApple", "Bubblegum", "BlueRaspberry", "GrapeSoda", "CherryBomb", "OrangeCream", "LemonDrop", "DarkMagic"}, 5, function(selectedTheme)
    local colors = Themes[selectedTheme]
    OuterBorder.BackgroundColor3 = colors.Accent
    MainFrame.BackgroundColor3 = colors.MainBG
    HeaderFrame.BackgroundColor3 = colors.Surface
    TabNavigationStrip.BackgroundColor3 = colors.MainBG
    KeybindCaptureBtn.TextColor3 = colors.Accent
    FovStroke.Color = colors.Accent
    SizeHandle.TextColor3 = colors.Accent
    TabNavigationStrip.ScrollBarImageColor3 = colors.Accent

    for name, tabObj in pairs(TabRegistry) do
        tabObj.Pane.ScrollBarImageColor3 = colors.Accent
        if name == ActiveTabName then 
            tabObj.Button.TextColor3 = colors.Accent 
            tabObj.Button.BackgroundColor3 = colors.Surface
            tabObj.Outline.Color = colors.Accent
        else 
            tabObj.Button.TextColor3 = colors.Text 
            tabObj.Button.BackgroundColor3 = Color3.fromRGB(24, 20, 24)
            tabObj.Outline.Color = Color3.fromRGB(45, 40, 45)
        end
        
        for _, element in ipairs(tabObj.Pane:GetChildren()) do
            if element:IsA("Frame") then
                element.BackgroundColor3 = colors.Surface
                local label = element:FindFirstChildOfClass("TextLabel") if label then label.TextColor3 = colors.Text end
                local tBox = element:FindFirstChildOfClass("TextBox") if tBox then tBox.TextColor3 = colors.Accent end
                local cBtn = element:FindFirstChildOfClass("TextButton")
                if cBtn and cBtn.Name == "TextButton" then cBtn.TextColor3 = colors.Accent end
            elseif element:IsA("TextLabel") then
                element.TextColor3 = colors.Muted
            end
        end
    end
end)

-- Open Initial Default Tab Panel
OpenTargetTabContainer("Main")

-- =============================================================================
-- SYSTEM HARDWARE LIFE-CYCLE LOOPS
-- =============================================================================
player.CharacterAdded:Connect(function(char)
    task.wait(0.3)
    local hum = char:WaitForChild("Humanoid")
    -- Enforce walkspeed toggle validation rule over automatic overrides on state load
    if RuntimeState.WalkspeedActive then 
        hum.WalkSpeed = RuntimeState.CurrentSpeed 
    else
        hum.WalkSpeed = 16
    end
    if RuntimeState.ShieldActive then ForceFieldInstance = Instance.new("ForceField") ForceFieldInstance.Parent = char end
end)

RunService.Heartbeat:Connect(function()
    pcall(function()
        local char = player.Character
        local hum = char and char:FindFirstChild("Humanoid")
        if hum then 
            -- Enforce toggled condition restriction instead of firing speed changes implicitly
            hum.WalkSpeed = RuntimeState.WalkspeedActive and RuntimeState.CurrentSpeed or 16 
        end
        if RuntimeState.HitboxActive then ProcessHitboxCalculations() end
        if RuntimeState.EspActive then ProcessGlobalEspEngine() end
    end)
end)

UserInputService.JumpRequest:Connect(function()
    if not RuntimeState.InfiniteJumpActive then return end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    local hum = player.Character and player.Character:FindFirstChild("Humanoid")
    if hum and root and hum.Health > 0 then root.Velocity = Vector3.new(root.Velocity.X, 65, root.Velocity.Z) end
end)

RunService.Stepped:Connect(function()
    if not RuntimeState.NoclipActive or not player.Character then return end
    for _, v in ipairs(player.Character:GetDescendants()) do
        if v:IsA("BasePart") then v.CanCollide = false end
    end
end)

RunService.RenderStepped:Connect(function(dt)
    if RuntimeState.ShowFovCircle then
        local targetCenter = Cam.ViewportSize / 2
        if RuntimeState.AimbotOriginMode == "Cursor" then targetCenter = UserInputService:GetMouseLocation() end
        FovCircleFrame.Position = UDim2.new(0, targetCenter.X, 0, targetCenter.Y - (RuntimeState.AimbotOriginMode == "Cursor" and 36 or 0))
        FovCircleFrame.Size = UDim2.new(0, RuntimeState.FovRadius * 2, 0, RuntimeState.FovRadius * 2)
    end

    if not RuntimeState.FlyActive or not player.Character then return end
    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local flightDir = Vector3.new()
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then flightDir += Cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then flightDir -= Cam.CFrame.LookVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then flightDir -= Cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then flightDir += Cam.CFrame.RightVector end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flightDir += Vector3.new(0,1,0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then flightDir -= Vector3.new(0,1,0) end
    
    if flightDir.Magnitude > 0 then root.CFrame = root.CFrame + (flightDir.Unit * (RuntimeState.CurrentSpeed * 1.4) * dt) end
    root.CFrame = CFrame.new(root.Position) * Cam.CFrame.Rotation
end)

-- Targeting Logic Loop: Handles Aimbot Locking & Virtualized Auto Shoot Mouse Clicks
RunService.RenderStepped:Connect(function()
    if not RuntimeState.AimbotActive and not RuntimeState.AutoShootActive then CleanActiveHighlight() return end
    pcall(function()
        local target = FetchOptimalAimbotVector()
        if target and target.Character then
            UpdatePlayerLockHighlight(target.Character)
            local targetPart = target.Character:FindFirstChild(RuntimeState.AimbotTargetPart)
            if targetPart then
                local aimLocationVector = targetPart.Position
                if RuntimeState.PredictionActive and target.Character:FindFirstChild("HumanoidRootPart") then
                    aimLocationVector = aimLocationVector + (target.Character.HumanoidRootPart.Velocity * RuntimeState.PredictionValue)
                end
                
                -- Execute Aimbot camera snap manipulation if active
                if RuntimeState.AimbotActive then
                    local lookCF = (aimLocationVector - Cam.CFrame.Position).Unit
                    Cam.CFrame = CFrame.new(Cam.CFrame.Position, Cam.CFrame.Position + lookCF)
                end
                
                -- Execute automated fast mouse-button click events if hover verification passes
                if RuntimeState.AutoShootActive then
                    task.spawn(function()
                        mouse1press()
                        task.wait(0.02)
                        mouse1release()
                    end)
                end
            end
        else
            CleanActiveHighlight()
        end
    end)
end)
