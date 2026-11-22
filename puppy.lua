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
    PredictMultiplier = 0.4
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
FovCircle.Name = "FovCircle"
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

-- 面板高度加高到 380
local Panel = Instance.new("Frame")
Panel.Size = UDim2.new(0, 240, 0, 380) 
Panel.Position = UDim2.new(1, -260, 0.1, 0) 
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

local BallStroke = Instance.new("UIStroke")
BallStroke.Color = Color3.fromRGB(255, 255, 255)
BallStroke.Thickness = 2
BallStroke.Transparency = 0.5
BallStroke.Parent = BallBtn

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
        if isPointInGui(Panel, point) or isPointInGui(BallBtn, point) then
            if isPointInGui(NameBox, point) then return end
            dragging = true
            dragStart = point
            dragDistance = 0
            currentTouchedBtn = nil
            
            if isPointInGui(Panel, point) then
                draggingGui = Panel
            elseif isPointInGui(BallBtn, point) then
                draggingGui = BallBtn
            end
            startPos = draggingGui.Position
            
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
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) and draggingGui then
        local delta = input.Position - dragStart
        dragDistance = math.abs(delta.X) + math.abs(delta.Y)
        draggingGui.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
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
local function createToggle(labelText, yPos, initialValue, callback)
    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(0, 150, 0, 25) 
    lbl.Position = UDim2.new(0, 15, 0, yPos)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(230, 230, 230)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 14
    lbl.ZIndex = 2
    lbl.Parent = Panel

    local toggleBtn = Instance.new("TextButton")
    toggleBtn.Size = UDim2.new(0, 44, 0, 24)
    toggleBtn.Position = UDim2.new(1, -59, 0, yPos + 0.5)
    toggleBtn.BackgroundColor3 = initialValue and Color3.fromRGB(0, 170, 0) or Color3.fromRGB(60, 60, 60)
    toggleBtn.Text = ""
    toggleBtn.AutoButtonColor = false
    toggleBtn.ZIndex = 2
    toggleBtn.Parent = Panel
    
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

createToggle("准心锁", 35, Config.Enabled, function(v) Config.Enabled = v; updateFovUI() end)
createToggle("墙体检测", 70, Config.WallCheck, function(v) Config.WallCheck = v end)
createToggle("透视 (ESP)", 105, Config.ESP, function(v) Config.ESP = v end)
createToggle("自动预判", 140, Config.Prediction, function(v) Config.Prediction = v end)

local MinBtn = Instance.new("TextButton")
MinBtn.Size = UDim2.new(0, 25, 0, 25)
MinBtn.Position = UDim2.new(1, -35, 0, 5) 
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
local FovLabel = Instance.new("TextLabel")
FovLabel.Size = UDim2.new(0, 100, 0, 30)
FovLabel.Position = UDim2.new(0, 15, 0, 180)
FovLabel.BackgroundTransparency = 1
FovLabel.Text = "FOV: " .. Config.FOV
FovLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
FovLabel.TextXAlignment = Enum.TextXAlignment.Left
FovLabel.Font = Enum.Font.GothamBold
FovLabel.TextSize = 14
FovLabel.ZIndex = 2
FovLabel.Parent = Panel

local MinusBtn = Instance.new("TextButton")
MinusBtn.Size = UDim2.new(0, 35, 0, 28)
MinusBtn.Position = UDim2.new(1, -95, 0, 181)
MinusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
MinusBtn.Text = "-"
MinusBtn.TextColor3 = Color3.new(1, 1, 1)
MinusBtn.TextSize = 20
MinusBtn.Font = Enum.Font.GothamBold
MinusBtn.ZIndex = 2
MinusBtn.Parent = Panel
local MinusCorner = Instance.new("UICorner")
MinusCorner.CornerRadius = UDim.new(0, 6)
MinusCorner.Parent = MinusBtn

local PlusBtn = Instance.new("TextButton")
PlusBtn.Size = UDim2.new(0, 50, 0, 28)
PlusBtn.Position = UDim2.new(1, -55, 0, 181)
PlusBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
PlusBtn.Text = "+"
PlusBtn.TextColor3 = Color3.new(1, 1, 1)
PlusBtn.TextSize = 20
PlusBtn.Font = Enum.Font.GothamBold
PlusBtn.ZIndex = 2
PlusBtn.Parent = Panel
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
local NameBox = Instance.new("TextBox")
NameBox.Size = UDim2.new(0, 155, 0, 30) 
NameBox.Position = UDim2.new(0, 15, 0, 220)
NameBox.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
NameBox.TextColor3 = Color3.new(1, 1, 1)
NameBox.PlaceholderText = "输入玩家/人机名"
NameBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
NameBox.Text = ""
NameBox.Font = Enum.Font.Gotham
NameBox.TextSize = 13
NameBox.ZIndex = 2
NameBox.Parent = Panel

local BoxCorner = Instance.new("UICorner")
BoxCorner.CornerRadius = UDim.new(0, 6)
BoxCorner.Parent = NameBox

local AddBtn = Instance.new("TextButton")
AddBtn.Size = UDim2.new(0, 50, 0, 30) 
AddBtn.Position = UDim2.new(1, -65, 0, 220)
AddBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
AddBtn.Text = "添加"
AddBtn.TextColor3 = Color3.new(1, 1, 1)
AddBtn.TextSize = 13
AddBtn.Font = Enum.Font.GothamBold
AddBtn.ZIndex = 2
AddBtn.Parent = Panel

local AddCorner = Instance.new("UICorner")
AddCorner.CornerRadius = UDim.new(0, 6)
AddCorner.Parent = AddBtn

-- 手动输入添加的逻辑复用（抽离成函数）
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
        print("[白名单] 已移除:", name)
    else
        table.insert(Whitelist, name)
        print("[白名单] 已添加:", name)
    end
end

registerButton(AddBtn, function()
    ToggleWhiteByName(NameBox.Text)
    NameBox.Text = ""
end)

-- === 新增：准心快捷加白按钮 (Y=265) ===
local AimAddBtn = Instance.new("TextButton")
AimAddBtn.Size = UDim2.new(1, -30, 0, 32) 
AimAddBtn.Position = UDim2.new(0, 15, 0, 265)
AimAddBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0) -- 橙色
AimAddBtn.Text = "准心加白 / 移除"
AimAddBtn.TextColor3 = Color3.new(1, 1, 1)
AimAddBtn.TextSize = 14
AimAddBtn.Font = Enum.Font.GothamBold
AimAddBtn.ZIndex = 2
AimAddBtn.Parent = Panel

local AimAddCorner = Instance.new("UICorner")
AimAddCorner.CornerRadius = UDim.new(0, 6)
AimAddCorner.Parent = AimAddBtn

-- 获取准星射线命中的目标
local function getTargetFromCrosshair()
    local center = Camera.ViewportSize / 2
    -- 从屏幕中心发射射线
    local ray = Camera:ViewportPointToRay(center.X, center.Y)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LP.Character} -- 过滤掉自己
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    
    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, raycastParams)
    if result and result.Instance then
        -- 向上寻找角色模型 (Player.Character 或 NPC)
        local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
        if hitModel and hitModel ~= workspace then
            local isPlayer = Players:GetPlayerFromCharacter(hitModel)
            local hasHumanoid = hitModel:FindFirstChildOfClass("Humanoid")
            if isPlayer or (hasHumanoid and not isPlayer) then
                return hitModel
            end
        end
    end
    return nil
end

registerButton(AimAddBtn, function()
    local targetModel = getTargetFromCrosshair()
    if targetModel then
        local targetName = targetModel.Name
        local player = Players:GetPlayerFromCharacter(targetModel)
        if player then targetName = player.Name end
        
        ToggleWhiteByName(targetName)
    else
        print("[白名单] 准心未指向任何玩家或人机")
    end
end)

-- === 卸载按钮 (Y=315) ===
local UnloadBtn = Instance.new("TextButton")
UnloadBtn.Size = UDim2.new(1, -30, 0, 35) 
UnloadBtn.Position = UDim2.new(0, 15, 0, 315)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
UnloadBtn.Text = "卸载脚本"
UnloadBtn.TextColor3 = Color3.new(1, 1, 1)
UnloadBtn.TextSize = 14
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.ZIndex = 2
UnloadBtn.Parent = Panel

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
print("[准心加白版] 已注入。支持一键锁定目标加白/移除。")
