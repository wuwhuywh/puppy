-- ============================================================
-- REDLINER 武器皮肤扫描器 (手机触控优化版)
-- 功能：扫描贴图 | 手动选择 | 拖动面板 | 一键复原 | 折叠悬浮球
-- ============================================================

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local lp = Players.LocalPlayer
local playerGui = lp:WaitForChild("PlayerGui")

-- 清理旧面板
local oldGui = playerGui:FindFirstChild("RedlinerMobileScanner")
if oldGui then oldGui:Destroy() end

-- ================= UI 构建 =================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RedlinerMobileScanner"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 999
screenGui.Parent = playerGui

-- 主面板 (适配手机屏幕大小)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainPanel"
mainFrame.Size = UDim2.new(0, 260, 0, 380) -- 缩小尺寸适配手机
mainFrame.Position = UDim2.new(0, 20, 0.5, -190) -- 默认放左侧防挡准星
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", mainFrame)
stroke.Color = Color3.fromRGB(180, 80, 255)
stroke.Thickness = 1.5
stroke.Transparency = 0.3

-- 标题栏 (用于拖动)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 35)
titleBar.BackgroundTransparency = 1
titleBar.Parent = mainFrame

local titleText = Instance.new("TextLabel")
titleText.Size = UDim2.new(1, -70, 1, 0)
titleText.Position = UDim2.new(0, 12, 0, 0)
titleText.BackgroundTransparency = 1
titleText.Text = "🎨 皮肤扫描器"
titleText.TextColor3 = Color3.fromRGB(220, 180, 255)
titleText.TextSize = 14
titleText.Font = Enum.Font.GothamBold
titleText.TextXAlignment = Enum.TextXAlignment.Left
titleText.Parent = titleBar

-- 折叠按钮 (变成悬浮球)
local foldBtn = Instance.new("TextButton")
foldBtn.Size = UDim2.new(0, 25, 0, 25)
foldBtn.Position = UDim2.new(1, -60, 0, 5)
foldBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
foldBtn.BackgroundTransparency = 0.5
foldBtn.Text = "-"
foldBtn.TextColor3 = Color3.new(1, 1, 1)
foldBtn.TextSize = 16
foldBtn.Font = Enum.Font.GothamBold
foldBtn.Parent = titleBar
Instance.new("UICorner", foldBtn).CornerRadius = UDim.new(1, 0)

-- 关闭按钮
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 25, 0, 25)
closeBtn.Position = UDim2.new(1, -30, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(1, 0)
closeBtn.MouseButton1Click:Connect(function() screenGui:Destroy() end)

-- 悬浮球 (折叠后显示)
local floatBall = Instance.new("TextButton")
floatBall.Size = UDim2.new(0, 50, 0, 50)
floatBall.Position = UDim2.new(0, 20, 0.5, -25)
floatBall.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
floatBall.BackgroundTransparency = 0.2
floatBall.Text = "🎨"
floatBall.TextSize = 24
floatBall.Visible = false
floatBall.Parent = screenGui
Instance.new("UICorner", floatBall).CornerRadius = UDim.new(1, 0)

-- 扫描按钮 (手机端加大)
local scanBtn = Instance.new("TextButton")
scanBtn.Size = UDim2.new(0.9, 0, 0, 40)
scanBtn.Position = UDim2.new(0.05, 0, 0, 45)
scanBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
scanBtn.BackgroundTransparency = 0.1
scanBtn.Text = "🔍 扫描当前皮肤"
scanBtn.TextColor3 = Color3.new(1, 1, 1)
scanBtn.TextSize = 15
scanBtn.Font = Enum.Font.GothamBold
scanBtn.Parent = mainFrame
Instance.new("UICorner", scanBtn).CornerRadius = UDim.new(0, 8)

-- 滚动展示框
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(0.9, 0, 0, 245)
scrollFrame.Position = UDim2.new(0.05, 0, 0, 95)
scrollFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
scrollFrame.BackgroundTransparency = 0.4
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 100, 255)
scrollFrame.ScrollingDirection = Enum.ScrollingDirection.Y
scrollFrame.Parent = mainFrame
Instance.new("UICorner", scrollFrame).CornerRadius = UDim.new(0, 8)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

-- 状态文字
local statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, 0, 0, 20)
statusText.Position = UDim2.new(0, 0, 1, -25)
statusText.BackgroundTransparency = 1
statusText.Text = "等待扫描..."
statusText.TextColor3 = Color3.fromRGB(150, 150, 150)
statusText.TextSize = 12
statusText.Font = Enum.Font.Gotham
statusText.Parent = mainFrame

-- ================= 拖动面板逻辑 (手机触控) =================
local dragging, dragInput, dragStart, startPos

local function updateInput(input)
    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
end

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        updateInput(input)
    end
end)

-- ================= 折叠/展开逻辑 =================
foldBtn.MouseButton1Click:Connect(function()
    mainFrame.Visible = false
    floatBall.Visible = true
    -- 让悬浮球出现在面板消失的位置
    floatBall.Position = UDim2.new(mainFrame.Position.X.Scale, mainFrame.Position.X.Offset, mainFrame.Position.Y.Scale, mainFrame.Position.Y.Offset)
end)

floatBall.MouseButton1Click:Connect(function()
    mainFrame.Visible = true
    floatBall.Visible = false
end)

-- ================= 核心逻辑 =================
local defaultSkins = {
    {name = "默认材质 (复原)", id = ""},
    {name = "霓虹紫 (Neon)", id = "rbxassetid://6031075931"},
    {name = "熔岩红 (Lava)", id = "rbxassetid://3707943717"},
    {name = "玻璃质感 (Glass)", id = "rbxassetid://72008530"},
    {name = "星空 (Galaxy)", id = "rbxassetid://3369273829"}
}

-- 应用皮肤
local function applySkinToWeapons(textureId)
    local function apply(tool)
        if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
            local handle = tool.Handle
            local mesh = handle:FindFirstChild("Mesh") or handle:FindFirstChildWhichIsA("SpecialMesh") or handle:FindFirstChildWhichIsA("MeshPart")
            if mesh then
                if mesh:IsA("SpecialMesh") then
                    mesh.TextureId = textureId
                elseif mesh:IsA("MeshPart") or mesh:IsA("BasePart") then
                    if mesh:FindFirstChild("Texture") then
                        mesh.Texture.Texture = textureId
                    else
                        pcall(function() mesh.TextureID = textureId end)
                    end
                end
            end
        end
    end

    if lp.Character then
        for _, v in ipairs(lp.Character:GetChildren()) do apply(v) end
    end
    local bp = lp:FindFirstChild("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do apply(v) end
    end
end

-- 添加列表项
local function addSkinEntry(name, id)
    local entryBtn = Instance.new("TextButton")
    entryBtn.Size = UDim2.new(1, -10, 0, 38) -- 手机端加大按钮高度
    entryBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    entryBtn.BackgroundTransparency = 0.5
    entryBtn.Text = "  " .. name
    entryBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
    entryBtn.TextSize = 13
    entryBtn.Font = Enum.Font.GothamMedium
    entryBtn.TextXAlignment = Enum.TextXAlignment.Left
    entryBtn.Parent = scrollFrame
    Instance.new("UICorner", entryBtn).CornerRadius = UDim.new(0, 6)

    entryBtn.MouseButton1Click:Connect(function()
        applySkinToWeapons(id)
        entryBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 200)
        task.delay(0.3, function() entryBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55) end)
        statusText.Text = "已应用: " .. name
    end)
end

-- 扫描功能
local function performScan()
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
    end
    
    local foundSkins = {}
    local seenIds = {}
    statusText.Text = "正在扫描..."

    local function checkTool(tool)
        if tool:IsA("Tool") and tool:FindFirstChild("Handle") then
            local handle = tool.Handle
            for _, v in ipairs(handle:GetChildren()) do
                if v:IsA("SpecialMesh") and v.TextureId ~= "" then
                    local id = v.TextureId
                    if not seenIds[id] then
                        table.insert(foundSkins, {name = tool.Name .. " - 贴图(" .. string.sub(id, -6) .. ")", id = id})
                        seenIds[id] = true
                    end
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    local id = v.Texture
                    if id ~= "" and not seenIds[id] then
                        table.insert(foundSkins, {name = tool.Name .. " - 贴花(" .. string.sub(id, -6) .. ")", id = id})
                        seenIds[id] = true
                    end
                end
            end
        end
    end

    if lp.Character then
        for _, v in ipairs(lp.Character:GetChildren()) do checkTool(v) end
    end
    local bp = lp:FindFirstChild("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do checkTool(v) end
    end

    if #foundSkins > 0 then
        for i, skin in ipairs(foundSkins) do addSkinEntry(skin.name, skin.id) end
        statusText.Text = string.format("找到 %d 个贴图", #foundSkins)
    else
        statusText.Text = "未找到可替换贴图"
    end

    -- 分割线
    local divider = Instance.new("Frame")
    divider.Size = UDim2.new(1, -10, 0, 1)
    divider.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    divider.BackgroundTransparency = 0.5
    divider.BorderSizePixel = 0
    divider.Parent = scrollFrame
    
    -- 默认皮肤
    for _, skin in ipairs(defaultSkins) do addSkinEntry("⭐ " .. skin.name, skin.id) end
end

scanBtn.MouseButton1Click:Connect(function()
    performScan()
    scanBtn.Text = "扫描中..."
    task.wait(0.5)
    scanBtn.Text = "🔍 扫描当前皮肤"
end)

print("[REDLINER] 手机端皮肤扫描器已加载！手指拖动标题栏可移动。")