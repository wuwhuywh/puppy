-- 防止重复注入导致内存泄漏
if getgenv().UnloadAim then
    getgenv().UnloadAim()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

local Config = {
    Enabled = true,
    AimPart = "Head",
    BodyLock = true,
    WallCheck = true,
    ESP = false,
    FOV = 150,
    BulletSpeed = 1000,
    Prediction = true,
    PredictMultiplier = 0.4,
    ShowTargetUI = true
}

local Whitelist = {}
local Connections = {}
local isUnloaded = false
local activeHighlights = {}
local ButtonRegistry = {}
local NPCCache = {} 

local function addConnection(conn)
    table.insert(Connections, conn)
end

local function isWhitelisted(entry)
    if not entry then return false end
    local targetName = tostring(entry)
    local targetId = nil
    if typeof(entry) == "Instance" and entry:IsA("Player") then
        targetName = entry.Name
        targetId = tostring(entry.UserId)
    elseif typeof(entry) == "Instance" and entry:IsA("Model") then
        targetName = entry.Name 
    end
    for _, whiteEntry in ipairs(Whitelist) do
        if string.lower(tostring(whiteEntry)) == string.lower(targetName) then return true end
        if targetId and tostring(whiteEntry) == targetId then return true end
    end
    return false
end

-- ================= 1. UI 构建 =================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AimAssistUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true 
local success, err = pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not success then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end

local FovCircle = Instance.new("Frame")
FovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FovCircle.Position = UDim2.new(0.5, 0, 0.5, 0)
FovCircle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
FovCircle.BackgroundTransparency = 1
FovCircle.Visible = Config.Enabled
FovCircle.Parent = ScreenGui

local FovCorner = Instance.new("UICorner")
FovCorner.CornerRadius = UDim.new(1, 0)
FovCorner.Parent = FovCircle

local FovStroke = Instance.new("UIStroke")
FovStroke.Color = Color3.fromRGB(0, 255, 255)
FovStroke.Thickness = 1.5
FovStroke.Transparency = 0.5
FovStroke.Parent = FovCircle

local function updateFovUI()
    FovCircle.Size = UDim2.fromOffset(Config.FOV * 2, Config.FOV * 2)
    FovCircle.Visible = Config.Enabled
end

-- === 独立外部：目标指示器 ===
local TargetFrame = Instance.new("Frame")
TargetFrame.Size = UDim2.new(0, 160, 0, 35)
TargetFrame.Position = UDim2.new(0.5, -80, 0.15, 0) 
TargetFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TargetFrame.BackgroundTransparency = 0.3
TargetFrame.BorderSizePixel = 0
TargetFrame.Visible = Config.ShowTargetUI
TargetFrame.ZIndex = 20
TargetFrame.Parent = ScreenGui

local TF_Corner = Instance.new("UICorner")
TF_Corner.CornerRadius = UDim.new(0, 6)
TF_Corner.Parent = TargetFrame

local TF_Stroke = Instance.new("UIStroke")
TF_Stroke.Color = Color3.fromRGB(0, 255, 255)
TF_Stroke.Thickness = 1.5
TF_Stroke.Parent = TargetFrame

local TargetDisplay = Instance.new("TextLabel")
TargetDisplay.Size = UDim2.new(1, 0, 1, 0)
TargetDisplay.BackgroundTransparency = 1
TargetDisplay.TextColor3 = Color3.fromRGB(150, 150, 150)
TargetDisplay.Font = Enum.Font.GothamBold
TargetDisplay.TextSize = 14
TargetDisplay.Text = "当前瞄准: 无"
TargetDisplay.ZIndex = 21
TargetDisplay.Parent = TargetFrame

-- === 主面板 ===
local Panel = Instance.new("Frame")
Panel.Size = UDim2.new(0, 240, 0, 320) 
Panel.Position = UDim2.new(1, -260, 0.2, 0) 
Panel.BackgroundTransparency = 1
Panel.Parent = ScreenGui

local BgFrame = Instance.new("Frame")
BgFrame.Size = UDim2.new(1, 0, 1, 0)
BgFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
BgFrame.BackgroundTransparency = 0.2
BgFrame.BorderSizePixel = 0
BgFrame.ZIndex = 1
BgFrame.Parent = Panel

local BgCorner = Instance.new("UICorner")
BgCorner.CornerRadius = UDim.new(0, 10)
BgCorner.Parent = BgFrame

local BgStroke = Instance.new("UIStroke")
BgStroke.Color = Color3.fromRGB(60, 60, 60)
BgStroke.Thickness = 1.5
BgStroke.Transparency = 0.5
BgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
BgStroke.Parent = BgFrame

-- === 内部滚动框 ===
local MainScroll = Instance.new("ScrollingFrame")
MainScroll.Size = UDim2.new(1, 0, 1, 0)
MainScroll.Position = UDim2.new(0, 0, 0, 0)
MainScroll.BackgroundTransparency = 1
MainScroll.BorderSizePixel = 0
MainScroll.ScrollBarThickness = 3
MainScroll.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
MainScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
MainScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
MainScroll.ZIndex = 2
MainScroll.Parent = Panel

local UIPadding = Instance.new("UIPadding")
UIPadding.PaddingTop = UDim.new(0, 40) 
UIPadding.PaddingBottom = UDim.new(0, 15)
UIPadding.PaddingLeft = UDim.new(0, 10)  
UIPadding.PaddingRight = UDim.new(0, 15) -- 加大右边距，防截断
UIPadding.Parent = MainScroll

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Parent = MainScroll

local BallBtn = Instance.new("TextButton")
BallBtn.Size = UDim2.new(0, 45, 0, 45)
BallBtn.Position = Panel.Position
BallBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
BallBtn.Text = "UI"
BallBtn.TextColor3 = Color3.new(1, 1, 1)
BallBtn.TextSize = 14
BallBtn.Font = Enum.Font.GothamBold
BallBtn.AutoButtonColor = false
BallBtn.Visible = false
BallBtn.ZIndex = 10
BallBtn.Parent = ScreenGui

local BallCorner = Instance.new("UICorner")
BallCorner.CornerRadius = UDim.new(1, 0)
BallCorner.Parent = BallBtn

-- ================= 2. 拖拽与点击逻辑 =================
local dragging = false
local dragStart, startPos, dragDistance = nil, nil, 0
local currentTouchedBtn = nil
local draggingGui = nil 

local function isPointInGui(gui, point)
    if not gui or not gui.Visible then return false end
    local pos = gui.AbsolutePosition
    local size = gui.AbsoluteSize
    return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

addConnection(UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local point = input.Position
        
        if isPointInGui(Panel, point) or isPointInGui(BallBtn, point) or isPointInGui(TargetFrame, point) then
            if isPointInGui(NameBox, point) then return end
            
            dragging = true
            dragStart = point
            dragDistance = 0
            currentTouchedBtn = nil
            
            if isPointInGui(Panel, point) then
                local scrollPos = MainScroll.AbsolutePosition
                local paddingTop = 40
                if point.Y < scrollPos.Y + paddingTop then
                    draggingGui = Panel
                else
                    draggingGui = nil 
                end
            elseif isPointInGui(BallBtn, point) then
                draggingGui = BallBtn
            elseif isPointInGui(TargetFrame, point) then
                draggingGui = TargetFrame
            end
            
            if draggingGui then
                startPos = draggingGui.Position
            end
            
            for _, data in ipairs(ButtonRegistry) do
                if isPointInGui(data.btn, point) then
                    currentTouchedBtn = data
                    break
                end
            end
        end
    end
end))

addConnection(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        dragDistance = math.abs(delta.X) + math.abs(delta.Y)
        
        if draggingGui then
            draggingGui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end))

addConnection(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            dragging = false
            if dragDistance < 10 and currentTouchedBtn then
                currentTouchedBtn.callback()
            end
            currentTouchedBtn = nil
            draggingGui = nil
        end
    end
end))

local function registerButton(btn, callback)
    btn.Active = false 
    table.insert(ButtonRegistry, {btn = btn, callback = callback})
end

registerButton(BallBtn, function()
    BallBtn.Visible = false
    Panel.Visible = true
    Panel.Position = BallBtn.Position
end)

-- ================= 3. 控件生成器 =================
local currentLayoutOrder = 1
local function getNewOrder()
    currentLayoutOrder = currentLayoutOrder + 1
    return currentLayoutOrder
end

local function createToggle(labelText, initialValue, callback)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, 0, 0, 30)
    container.BackgroundTransparency = 1
    container.LayoutOrder = getNewOrder()
    container.Parent = MainScroll

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 150, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.ZIndex = 2
    lbl.Parent = container

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 44, 0, 24)
    -- 安全距离：X坐标向右偏移 -48（给滚动条让出空间）
    toggleBtn.Position = UDim2.new(1, -48, 0.5, -12) 
    toggleBtn.BackgroundColor3 = initialValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 60)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 2
    toggleBtn.Parent = container
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(1, 0)
    toggleCorner.Parent = toggleBtn

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = initialValue and UDim2.new(0, 22, 0, 2) or UDim2.new(0, 2, 0, 2)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.ZIndex = 3
    knob.Parent = toggleBtn

    local knobCorner = Instance.new("UICorner")
    knobCorner.CornerRadius = UDim.new(1, 0)
    knobCorner.Parent = knob

    local state = initialValue
    registerButton(toggleBtn, function()
        state = not state
        local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(toggleBtn, tweenInfo, {BackgroundColor3 = state and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 60)}):Play()
        TweenService:Create(knob, tweenInfo, {Position = state and UDim2.new(0, 22, 0, 2) or UDim2.new(0, 2, 0, 2)}):Play()
        callback(state)
    end)
end

createToggle("准心锁", Config.Enabled, function(v) Config.Enabled = v; updateFovUI() end)
createToggle("墙体检测", Config.WallCheck, function(v) Config.WallCheck = v end)
createToggle("透视 (ESP)", Config.ESP, function(v) Config.ESP = v end)
createToggle("自动预判", Config.Prediction, function(v) Config.Prediction = v end)
createToggle("显示目标框", Config.ShowTargetUI, function(v) Config.ShowTargetUI = v; TargetFrame.Visible = v end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 25, 0, 25)
MinBtn.Position = UDim2.new(1, -35, 0, 8) 
MinBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
MinBtn.Text = "-"
MinBtn.TextColor3 = Color3.new(1, 1, 1)
MinBtn.TextSize = 18
MinBtn.Font = Enum.Font.GothamBold
MinBtn.ZIndex = 3
MinBtn.Parent = Panel
local MinCorner = Instance.new("UICorner")
MinCorner.CornerRadius = UDim.new(1, 0)
MinCorner.Parent = MinBtn

registerButton(MinBtn, function()
    Panel.Visible = false
    BallBtn.Visible = true
    BallBtn.Position = Panel.Position
end)

-- === FOV 调节区 ===
local FovContainer = Instance.new("Frame")
FovContainer.Size = UDim2.new(1, 0, 0, 30)
FovContainer.BackgroundTransparency = 1
FovContainer.LayoutOrder = getNewOrder()
FovContainer.Parent = MainScroll

local FovLabel = Instance.new("TextLabel")
FovLabel.Size = UDim2.new(0, 80, 1, 0)
FovLabel.BackgroundTransparency = 1
FovLabel.Text = "FOV: " .. Config.FOV
FovLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
FovLabel.TextXAlignment = Enum.TextXAlignment.Left
FovLabel.Font = Enum.Font.GothamBold
FovLabel.TextSize = 14
FovLabel.ZIndex = 2
FovLabel.Parent = FovContainer

local MinusBtn = Instance.new("TextButton")
MinusBtn.Size = UDim2.new(0, 35, 0, 28)
MinusBtn.Position = UDim2.new(1, -85, 0, 1)
MinusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
MinusBtn.Text = "-"
MinusBtn.TextColor3 = Color3.new(1, 1, 1)
MinusBtn.TextSize = 20
MinusBtn.Font = Enum.Font.GothamBold
MinusBtn.ZIndex = 2
MinusBtn.Parent = FovContainer
local MinusCorner = Instance.new("UICorner")
MinusCorner.CornerRadius = UDim.new(0, 6)
MinusCorner.Parent = MinusBtn

local PlusBtn = Instance.new("TextButton")
PlusBtn.Size = UDim2.new(0, 45, 0, 28)
PlusBtn.Position = UDim2.new(1, -45, 0, 1)
PlusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
PlusBtn.Text = "+"
PlusBtn.TextColor3 = Color3.new(1, 1, 1)
PlusBtn.TextSize = 20
PlusBtn.Font = Enum.Font.GothamBold
PlusBtn.ZIndex = 2
PlusBtn.Parent = FovContainer
local PlusCorner = Instance.new("UICorner")
PlusCorner.CornerRadius = UDim.new(0, 6)
PlusCorner.Parent = PlusBtn

registerButton(MinusBtn, function()
    Config.FOV = math.max(20, Config.FOV - 20)
    FovLabel.Text = "FOV: " .. Config.FOV
    updateFovUI()
end)

registerButton(PlusBtn, function()
    Config.FOV = math.min(500, Config.FOV + 20)
    FovLabel.Text = "FOV: " .. Config.FOV
    updateFovUI()
end)

-- === 白名单输入区 ===
local NameInputContainer = Instance.new("Frame")
NameInputContainer.Size = UDim2.new(1, 0, 0, 30)
NameInputContainer.BackgroundTransparency = 1
NameInputContainer.LayoutOrder = getNewOrder()
NameInputContainer.Parent = MainScroll

local NameBox = Instance.new("TextBox")
NameBox.Size = UDim2.new(1, -55, 1, 0) 
NameBox.Position = UDim2.new(0, 0, 0, 0)
NameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
NameBox.TextColor3 = Color3.new(1, 1, 1)
NameBox.PlaceholderText = "输入玩家/人机名"
NameBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
NameBox.Text = ""
NameBox.Font = Enum.Font.Gotham
NameBox.TextSize = 13
NameBox.ZIndex = 2
NameBox.Parent = NameInputContainer

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = NameBox

local AddBtn = Instance.new("TextButton")
AddBtn.Size = UDim2.new(0, 50, 0, 30) 
AddBtn.Position = UDim2.new(1, -50, 0, 0)
AddBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
AddBtn.Text = "添加"
AddBtn.TextColor3 = Color3.new(1, 1, 1)
AddBtn.TextSize = 13
AddBtn.Font = Enum.Font.GothamBold
AddBtn.ZIndex = 2
AddBtn.Parent = NameInputContainer

local AddCorner = Instance.new("UICorner")
AddCorner.CornerRadius = UDim.new(0, 6)
AddCorner.Parent = AddBtn

-- 准心快捷加白 / 移除
local AimButtonsContainer = Instance.new("Frame")
AimButtonsContainer.Size = UDim2.new(1, 0, 0, 32)
AimButtonsContainer.BackgroundTransparency = 1
AimButtonsContainer.LayoutOrder = getNewOrder()
AimButtonsContainer.Parent = MainScroll

local AimAddBtn = Instance.new("TextButton")
AimAddBtn.Size = UDim2.new(0.5, -5, 1, 0) 
AimAddBtn.Position = UDim2.new(0, 0, 0, 0)
AimAddBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
AimAddBtn.Text = "准心加白"
AimAddBtn.TextColor3 = Color3.new(1, 1, 1)
AimAddBtn.TextSize = 13
AimAddBtn.Font = Enum.Font.GothamBold
AimAddBtn.ZIndex = 2
AimAddBtn.Parent = AimButtonsContainer

local AimAddCorner = Instance.new("UICorner")
AimAddCorner.CornerRadius = UDim.new(0, 6)
AimAddCorner.Parent = AimAddBtn

local AimRemoveBtn = Instance.new("TextButton")
AimRemoveBtn.Size = UDim2.new(0.5, -5, 1, 0) 
AimRemoveBtn.Position = UDim2.new(0.5, 5, 0, 0)
AimRemoveBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
AimRemoveBtn.Text = "准心移除"
AimRemoveBtn.TextColor3 = Color3.new(1, 1, 1)
AimRemoveBtn.TextSize = 13
AimRemoveBtn.Font = Enum.Font.GothamBold
AimRemoveBtn.ZIndex = 2
AimRemoveBtn.Parent = AimButtonsContainer

local AimRemCorner = Instance.new("UICorner")
AimRemCorner.CornerRadius = UDim.new(0, 6)
AimRemCorner.Parent = AimRemoveBtn

-- === 白名单列表 ===
local WhitelistContainer = Instance.new("Frame")
WhitelistContainer.Size = UDim2.new(1, 0, 0, 0)
WhitelistContainer.AutomaticSize = Enum.AutomaticSize.Y
WhitelistContainer.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
WhitelistContainer.BorderSizePixel = 0
WhitelistContainer.LayoutOrder = getNewOrder()
WhitelistContainer.ZIndex = 2
WhitelistContainer.Parent = MainScroll

local WC_Corner = Instance.new("UICorner")
WC_Corner.CornerRadius = UDim.new(0, 6)
WC_Corner.Parent = WhitelistContainer

local WC_ListLayout = Instance.new("UIListLayout")
WC_ListLayout.Padding = UDim.new(0, 4)
WC_ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
WC_ListLayout.Parent = WhitelistContainer

local WC_Padding = Instance.new("UIPadding")
WC_Padding.PaddingTop = UDim.new(0, 5)
WC_Padding.PaddingBottom = UDim.new(0, 5)
WC_Padding.PaddingLeft = UDim.new(0, 5)
WC_Padding.PaddingRight = UDim.new(0, 5)
WC_Padding.Parent = WhitelistContainer

local function RefreshWhitelistUI()
    for _, child in ipairs(WhitelistContainer:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    
    if #Whitelist == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 25)
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Text = "无白名单记录"
        emptyLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
        emptyLabel.TextSize = 12
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.ZIndex = 3
        emptyLabel.Parent = WhitelistContainer
        return
    end

    for i, name in ipairs(Whitelist) do
        local item = Instance.new("TextButton")
        item.Size = UDim2.new(1, 0, 0, 25)
        item.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        item.Text = name
        item.TextColor3 = Color3.new(1, 1, 1)
        item.TextSize = 12
        item.Font = Enum.Font.Gotham
        item.ZIndex = 3
        item.LayoutOrder = i
        item.Parent = WhitelistContainer
        
        local itemCorner = Instance.new("UICorner")
        itemCorner.CornerRadius = UDim.new(0, 4)
        itemCorner.Parent = item
        
        item.MouseButton1Click:Connect(function()
            for idx, val in ipairs(Whitelist) do
                if val == name then
                    table.remove(Whitelist, idx)
                    break
                end
            end
            RefreshWhitelistUI()
        end)
    end
end

local function ToggleWhiteByName(name)
    if name == "" then return end
    local foundIndex = nil
    for i, v in ipairs(Whitelist) do
        if string.lower(tostring(v)) == string.lower(name) then
            foundIndex = i
            break
        end
    end
    if foundIndex then
        table.remove(Whitelist, foundIndex)
    else
        table.insert(Whitelist, name)
    end
    RefreshWhitelistUI()
end

registerButton(AddBtn, function()
    ToggleWhiteByName(NameBox.Text)
    NameBox.Text = ""
end)

local function getTargetOnCrosshairIgnoreWalls()
    local lookVector = Camera.CFrame.LookVector
    local camPos = Camera.CFrame.Position
    local bestTargetName = nil
    local bestDot = 0.98 
    
    local function checkModel(model)
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        local part = model:FindFirstChild(Config.AimPart) or model:FindFirstChild("HumanoidRootPart")
        if not part then return end
        local direction = (part.Position - camPos).Unit
        local dot = direction:Dot(lookVector)
        if dot > bestDot then
            bestDot = dot
            local player = Players:GetPlayerFromCharacter(model)
            bestTargetName = player and player.Name or model.Name
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then checkModel(p.Character) end
    end
    for _, npc in ipairs(NPCCache) do
        if npc and npc.Parent then checkModel(npc) end
    end
    return bestTargetName
end

registerButton(AimAddBtn, function()
    local targetName = getTargetOnCrosshairIgnoreWalls()
    if targetName and not isWhitelisted(targetName) then
        table.insert(Whitelist, targetName)
        RefreshWhitelistUI()
    end
end)

registerButton(AimRemoveBtn, function()
    local targetName = getTargetOnCrosshairIgnoreWalls()
    if targetName then
        for i, v in ipairs(Whitelist) do
            if string.lower(tostring(v)) == string.lower(targetName) then
                table.remove(Whitelist, i)
                break
            end
        end
        RefreshWhitelistUI()
    end
end)

task.spawn(function()
    while not isUnloaded do
        task.wait(0.1)
        if Config.ShowTargetUI then
            local targetName = getTargetOnCrosshairIgnoreWalls()
            if targetName then
                TargetDisplay.Text = "瞄准: " .. targetName
                if isWhitelisted(targetName) then
                    TargetDisplay.TextColor3 = Color3.fromRGB(0, 255, 0)
                    TF_Stroke.Color = Color3.fromRGB(0, 255, 0)
                else
                    TargetDisplay.TextColor3 = Color3.fromRGB(255, 80, 80)
                    TF_Stroke.Color = Color3.fromRGB(255, 80, 80)
                end
            else
                TargetDisplay.Text = "瞄准: 无"
                TargetDisplay.TextColor3 = Color3.fromRGB(150, 150, 150)
                TF_Stroke.Color = Color3.fromRGB(60, 60, 60)
            end
        end
    end
end)

local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(1, 0, 0, 35) 
UnloadBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
UnloadBtn.Text = "卸载脚本"
UnloadBtn.TextColor3 = Color3.new(1, 1, 1)
UnloadBtn.TextSize = 14
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.ZIndex = 2
UnloadBtn.LayoutOrder = getNewOrder()
UnloadBtn.Parent = MainScroll

local UnloadCorner = Instance.new("UICorner")
UnloadCorner.CornerRadius = UDim.new(0, 6)
UnloadCorner.Parent = UnloadBtn

local function UnloadAim()
    isUnloaded = true
    Config.Enabled = false
    Config.ESP = false

    for _, hl in pairs(activeHighlights) do
        if hl and hl.Parent then hl:Destroy() end
    end
    activeHighlights = {}

    for _, conn in pairs(Connections) do
        pcall(function() conn:Disconnect() end)
    end
    Connections = {}

    if ScreenGui and ScreenGui.Parent then ScreenGui:Destroy() end

    getgenv().UnloadAim = nil
    print("[AimAssist] 脚本已完全卸载。")
end

registerButton(UnloadBtn, UnloadAim)
getgenv().UnloadAim = UnloadAim

-- ================= 4. 人机扫描与透视 =================
task.spawn(function()
    while not isUnloaded do
        local newCache = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Model") and obj ~= LP.Character then
                local hum = obj:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then
                    if not Players:GetPlayerFromCharacter(obj) then
                        table.insert(newCache, obj)
                    end
                end
            end
        end
        NPCCache = newCache
        task.wait(1.5)
    end
end)

local function applyESP(model, isWhite)
    if not model or not model.Parent then return end
    local highlight = model:FindFirstChild("BrutalESP")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "BrutalESP"
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = model
        activeHighlights[model] = highlight
    end
    if isWhite then
        highlight.FillColor = Color3.fromRGB(0, 255, 0)
        highlight.OutlineColor = Color3.fromRGB(0, 255, 0)
    else
        if Players:GetPlayerFromCharacter(model) then
            highlight.FillColor = Color3.fromRGB(255, 0, 0)
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        else
            highlight.FillColor = Color3.fromRGB(255, 165, 0) 
            highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
        end
    end
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
end

local function removeESP(model)
    if model and activeHighlights[model] then
        activeHighlights[model]:Destroy()
        activeHighlights[model] = nil
    end
end

task.spawn(function()
    while not isUnloaded do
        task.wait(0.5)
        if Config.ESP then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LP and p.Character then
                    applyESP(p.Character, isWhitelisted(p))
                end
            end
            for _, npc in ipairs(NPCCache) do
                if npc and npc.Parent then
                    applyESP(npc, isWhitelisted(npc.Name))
                end
            end
        else
            for model, _ in pairs(activeHighlights) do
                removeESP(model)
            end
        end
    end
end)

-- ================= 5. 统一自瞄 =================
local function getClosestToCrosshair()
    local center = Camera.ViewportSize / 2
    local closestPart = nil
    local predictedPos = nil
    local shortestDist = Config.FOV
    
    local function checkTarget(model, isWhite)
        if isWhite or not model then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        local part = model:FindFirstChild(Config.AimPart) or model:FindFirstChild("HumanoidRootPart")
        local hrp = model:FindFirstChild("HumanoidRootPart")
        
        if hum and hum.Health > 0 and part then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                local dist = (Vector2.new(screenPos.X, screenPos.Y) - center).Magnitude
                if dist < shortestDist then
                    local visible = true
                    if Config.WallCheck then
                        local raycastParams = RaycastParams.new()
                        raycastParams.FilterDescendantsInstances = {LP.Character, model}
                        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
                        raycastParams.IgnoreWater = true
                        local result = workspace:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, raycastParams)
                        if result then visible = false end
                    end
                    if visible then
                        shortestDist = dist
                        closestPart = part
                        
                        if Config.Prediction and hrp then
                            local targetVel = hrp.AssemblyLinearVelocity
                            local dist3D = (part.Position - Camera.CFrame.Position).Magnitude
                            local travelTime = dist3D / Config.BulletSpeed
                            predictedPos = part.Position + (targetVel * travelTime * Config.PredictMultiplier)
                        else
                            predictedPos = part.Position
                        end
                    end
                end
            end
        end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            checkTarget(p.Character, isWhitelisted(p))
        end
    end
    
    for _, npc in ipairs(NPCCache) do
        if npc and npc.Parent then
            checkTarget(npc, isWhitelisted(npc.Name))
        end
    end

    return closestPart, predictedPos
end

addConnection(RunService.RenderStepped:Connect(function()
    if isUnloaded or not Config.Enabled then return end
    
    local target, aimPos = getClosestToCrosshair()
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    if target and aimPos and hrp then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, aimPos)
        if Config.BodyLock then
            local currentPos = hrp.Position
            hrp.CFrame = CFrame.lookAt(currentPos, Vector3.new(aimPos.X, currentPos.Y, aimPos.Z))
        end
    end
end))

updateFovUI()
RefreshWhitelistUI() 
print("[UI开关修复] 已注入。开关不再被右侧截断。")
