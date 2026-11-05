--=====================================================================
--  刀刃球 Blade Ball | 自动弹反
--  功能：精准(1-100) / 范围(1-10) 滑动条 + 自动调整 + 脚下检测圈
--        拟人化随机延迟 + 精准上限保护
--        [新增] 收起时销毁面板 ScreenGui + 双重 Kick Hook
--=====================================================================

local Players             = game:GetService("Players")
local UserInputService    = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Camera      = workspace.CurrentCamera
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

--=====================================================================
--  防护模块：Kick Hook
--  放在最顶部，先于任何 UI / 游戏逻辑生效
--  两种方式互相兜底：
--    1) hookmetamethod 拦截 __namecall，覆盖 "LocalPlayer:Kick()"
--    2) hookfunction 拦截 LocalPlayer.Kick 本身，覆盖局部化引用
--=====================================================================
do
    -- 方式一：__namecall
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if self == LocalPlayer and (method == "Kick" or method == "kick") then
                return -- 静默拦截
            end
            return oldNamecall(self, ...)
        end)
    end)

    -- 方式二：直接替换 LocalPlayer.Kick
    pcall(function()
        if typeof(hookfunction) == "function" then
            local oldKick = LocalPlayer.Kick
            LocalPlayer.Kick = newcclosure(function(self, ...)
                if self == LocalPlayer then
                    return -- 静默拦截
                end
                return oldKick(self, ...)
            end)
        end
    end)
end

--------------------------------------------------------------------
-- 1. 配置与状态
--------------------------------------------------------------------
local CONFIG = {
    BaseRadius      = 2.0,   -- 范围=1 时圆圈半径(studs)
    BaseWindow      = 0.45,  -- 精准=1 时的时间窗口(秒)
    MinWindow       = 0.03,  -- 精准=100 时的时间窗口(秒)
    WindowFloor     = 0.05,  -- 时间窗口地板
    ParryCooldown   = 0.15,  -- 两次弹反最小间隔
    CircleHeight    = 2.8,   -- 圆圈在脚下多深
    CircleTrans     = 0.72,  -- 圆圈透明度
    HumanDelayMin   = 0.02,  -- 拟人化延迟下限
    HumanDelayMax   = 0.08,  -- 拟人化延迟上限
    PrecisionCap    = 95,    -- 自动调整时精准上限
}

local STATE = {
    Enabled    = false,
    ShowCircle = true,
    AutoAdjust = true,
    Precision  = 50,
    Range      = 5,
    ParryCount = 0,
    LastParry  = 0,
    CurrentBallSpeed = 0,
}

local THEME = {
    Accent  = Color3.fromRGB(0, 170, 255),
    BG      = Color3.fromRGB(24, 24, 30),
    BG2     = Color3.fromRGB(36, 36, 44),
    Text    = Color3.fromRGB(235, 235, 240),
    SubText = Color3.fromRGB(150, 150, 162),
    Green   = Color3.fromRGB(0, 196, 120),
    Red     = Color3.fromRGB(230, 70, 70),
    Orange  = Color3.fromRGB(255, 160, 40),
}

--------------------------------------------------------------------
-- 2. UI 工具
--------------------------------------------------------------------
local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness
    s.Transparency = transparency
    s.Parent = parent
    return s
end

local function makeLabel(parent, props)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 14
    label.TextColor3 = THEME.Text
    for k, v in pairs(props) do label[k] = v end
    label.Parent = parent
    return label
end

local function makeDraggable(frame, handle, onTap)
    handle = handle or frame
    local dragging, dragStart, startPos, moved = false, nil, nil, 0

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            moved = 0
            dragStart = input.Position
            startPos = frame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            if delta.Magnitude > moved then moved = delta.Magnitude end
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if onTap and moved < 6 then onTap() end
        end
    end)
end

local function makeSlider(parent, props)
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1, -24, 0, 38)
    container.Position = UDim2.fromOffset(12, props.Y)
    container.BackgroundTransparency = 1
    container.Parent = parent

    local label = makeLabel(container, {
        Text = props.Label .. "：" .. props.Default,
        Size = UDim2.new(1, 0, 0, 16),
        TextXAlignment = Enum.TextXAlignment.Left,
        TextSize = 13,
        TextColor3 = THEME.SubText,
    })

    local track = Instance.new("Frame")
    track.Size = UDim2.new(1, 0, 0, 8)
    track.Position = UDim2.new(0, 0, 0, 24)
    track.BackgroundColor3 = THEME.BG2
    track.BorderSizePixel = 0
    track.Parent = container
    addCorner(track, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((props.Default - props.Min) / (props.Max - props.Min), 0, 1, 0)
    fill.BackgroundColor3 = THEME.Accent
    fill.BorderSizePixel = 0
    fill.Parent = track
    addCorner(fill, 4)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.fromOffset(14, 14)
    knob.Position = UDim2.new((props.Default - props.Min) / (props.Max - props.Min), -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = track
    addCorner(knob, 999)

    local value = props.Default
    local dragging = false

    local function setValue(v, fire)
        v = math.clamp(v, props.Min, props.Max)
        if props.Integer then v = math.floor(v + 0.5) end
        value = v
        local ratio = (v - props.Min) / (props.Max - props.Min)
        fill.Size = UDim2.new(ratio, 0, 1, 0)
        knob.Position = UDim2.new(ratio, -7, 0.5, -7)
        label.Text = props.Label .. "：" .. (props.Integer and tostring(math.floor(v))
            or string.format("%.1f", v))
        if fire and props.OnChanged then props.OnChanged(v) end
    end

    local function updateFromX(x)
        local absX  = track.AbsolutePosition.X
        local width = track.AbsoluteSize.X
        if width <= 0 then return end
        local ratio = math.clamp((x - absX) / width, 0, 1)
        setValue(props.Min + ratio * (props.Max - props.Min), true)
    end

    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            updateFromX(input.Position.X)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)

    return {
        SetValue = function(v) setValue(v, false) end,
        GetValue = function() return value end,
    }
end

--------------------------------------------------------------------
-- 3. 创建 UI
--   mainGui   : 面板，收起时 Parent = nil（彻底离开数据模型）
--   floatGui  : 悬浮球，常驻，特征极小
--------------------------------------------------------------------
local viewport = Camera.ViewportSize

-- 悬浮球 ScreenGui（常驻）
local floatGui = Instance.new("ScreenGui")
floatGui.Name = "BladeBallFloat"
floatGui.ResetOnSpawn = false
floatGui.IgnoreGuiInset = true
floatGui.DisplayOrder = 1000
floatGui.Parent = PlayerGui

-- 面板 ScreenGui（可被整体移除）
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "BladeBallMain"
mainGui.ResetOnSpawn = false
mainGui.IgnoreGuiInset = true
mainGui.DisplayOrder = 999
mainGui.Parent = PlayerGui

-- ===== 主面板 =====
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(260, 292)
panel.Position = UDim2.fromOffset(math.max(20, viewport.X - 280), 64)
panel.BackgroundColor3 = THEME.BG
panel.BorderSizePixel = 0
panel.Parent = mainGui
addCorner(panel, 10)
addStroke(panel, THEME.Accent, 1, 0.55)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 34)
titleBar.BackgroundColor3 = THEME.BG2
titleBar.BorderSizePixel = 0
titleBar.Parent = panel
addCorner(titleBar, 10)

local titleMask = Instance.new("Frame")
titleMask.Size = UDim2.new(1, 0, 0, 10)
titleMask.Position = UDim2.new(0, 0, 1, -10)
titleMask.BackgroundColor3 = THEME.BG2
titleMask.BorderSizePixel = 0
titleMask.Parent = titleBar

makeLabel(titleBar, {
    Text = "刀刃球助手",
    Size = UDim2.new(1, -80, 1, 0),
    Position = UDim2.fromOffset(12, 0),
    TextXAlignment = Enum.TextXAlignment.Left,
    Font = Enum.Font.GothamBold,
    TextSize = 14,
})

local collapseBtn = Instance.new("TextButton")
collapseBtn.Size = UDim2.fromOffset(24, 24)
collapseBtn.Position = UDim2.new(1, -32, 0, 5)
collapseBtn.BackgroundColor3 = THEME.Red
collapseBtn.Text = "—"
collapseBtn.TextColor3 = Color3.new(1, 1, 1)
collapseBtn.Font = Enum.Font.GothamBold
collapseBtn.TextSize = 14
collapseBtn.AutoButtonColor = false
collapseBtn.Parent = titleBar
addCorner(collapseBtn, 6)

local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(1, -24, 0, 38)
toggleBtn.Position = UDim2.fromOffset(12, 44)
toggleBtn.BackgroundColor3 = THEME.BG2
toggleBtn.Text = "自动弹反：关"
toggleBtn.TextColor3 = THEME.Text
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.TextSize = 14
toggleBtn.AutoButtonColor = false
toggleBtn.Parent = panel
addCorner(toggleBtn, 8)
local toggleStroke = addStroke(toggleBtn, THEME.Red, 1, 0.25)

local smooth = { precision = STATE.Precision, range = STATE.Range }

local precisionSlider = makeSlider(panel, {
    Label = "精准", Min = 1, Max = 100, Default = STATE.Precision,
    Y = 90, Integer = true,
    OnChanged = function(v)
        STATE.Precision = v
        smooth.precision = v
    end,
})

local rangeSlider = makeSlider(panel, {
    Label = "范围", Min = 1, Max = 10, Default = STATE.Range,
    Y = 132, Integer = true,
    OnChanged = function(v)
        STATE.Range = v
        smooth.range = v
    end,
})

local autoBtn = Instance.new("TextButton")
autoBtn.Size = UDim2.new(1, -24, 0, 28)
autoBtn.Position = UDim2.fromOffset(12, 178)
autoBtn.BackgroundColor3 = THEME.BG2
autoBtn.Text = "自动调整：开"
autoBtn.TextColor3 = THEME.Text
autoBtn.Font = Enum.Font.GothamBold
autoBtn.TextSize = 13
autoBtn.AutoButtonColor = false
autoBtn.Parent = panel
addCorner(autoBtn, 6)
local autoStroke = addStroke(autoBtn, THEME.Green, 1, 0.2)

local circleBtn = Instance.new("TextButton")
circleBtn.Size = UDim2.new(1, -24, 0, 28)
circleBtn.Position = UDim2.fromOffset(12, 212)
circleBtn.BackgroundColor3 = THEME.BG2
circleBtn.Text = "显示圆圈：开"
circleBtn.TextColor3 = THEME.Text
circleBtn.Font = Enum.Font.GothamBold
circleBtn.TextSize = 13
circleBtn.AutoButtonColor = false
circleBtn.Parent = panel
addCorner(circleBtn, 6)
local circleStroke = addStroke(circleBtn, THEME.Green, 1, 0.2)

local statusLabel = makeLabel(panel, {
    Text = "状态：待机",
    Size = UDim2.new(1, -24, 0, 24),
    Position = UDim2.fromOffset(12, 250),
    TextXAlignment = Enum.TextXAlignment.Left,
    TextSize = 12,
    TextColor3 = THEME.SubText,
})

-- ===== 悬浮球（在 floatGui 里）=====
local floatBtn = Instance.new("TextButton")
floatBtn.Size = UDim2.fromOffset(54, 54)
floatBtn.Position = UDim2.fromOffset(math.max(20, viewport.X - 74), 300)
floatBtn.BackgroundColor3 = THEME.BG2
floatBtn.Text = "刃"
floatBtn.TextColor3 = THEME.Text
floatBtn.Font = Enum.Font.GothamBold
floatBtn.TextSize = 22
floatBtn.AutoButtonColor = false
floatBtn.Visible = false
floatBtn.Parent = floatGui
addCorner(floatBtn, 999)
local floatStroke = addStroke(floatBtn, THEME.Accent, 2, 0.2)

--------------------------------------------------------------------
-- 4. 刷新 UI
--------------------------------------------------------------------
local function refreshUI()
    if STATE.Enabled then
        toggleBtn.Text = "自动弹反：开"
        toggleBtn.BackgroundColor3 = THEME.Green
        toggleBtn.TextColor3 = Color3.new(1, 1, 1)
        toggleStroke.Color = THEME.Green
        toggleStroke.Transparency = 0.2
        floatBtn.BackgroundColor3 = THEME.Green
        floatStroke.Color = THEME.Green
        statusLabel.TextColor3 = THEME.Green
    else
        toggleBtn.Text = "自动弹反：关"
        toggleBtn.BackgroundColor3 = THEME.BG2
        toggleBtn.TextColor3 = THEME.Text
        toggleStroke.Color = THEME.Red
        toggleStroke.Transparency = 0.25
        floatBtn.BackgroundColor3 = THEME.BG2
        floatStroke.Color = THEME.Accent
        statusLabel.TextColor3 = THEME.SubText
    end

    autoBtn.Text = "自动调整：" .. (STATE.AutoAdjust and "开" or "关")
    autoBtn.BackgroundColor3 = STATE.AutoAdjust and THEME.Green or THEME.BG2
    autoBtn.TextColor3 = STATE.AutoAdjust and Color3.new(1, 1, 1) or THEME.Text
    autoStroke.Color = STATE.AutoAdjust and THEME.Green or THEME.Red

    circleBtn.Text = "显示圆圈：" .. (STATE.ShowCircle and "开" or "关")
    circleBtn.BackgroundColor3 = STATE.ShowCircle and THEME.Green or THEME.BG2
    circleBtn.TextColor3 = STATE.ShowCircle and Color3.new(1, 1, 1) or THEME.Text
    circleStroke.Color = STATE.ShowCircle and THEME.Green or THEME.Red

    if STATE.Enabled then
        statusLabel.Text = string.format("精准 %d | 范围 %d | 弹反 %d 次",
            STATE.Precision, STATE.Range, STATE.ParryCount)
    else
        statusLabel.Text = "状态：待机"
    end
end
refreshUI()

--------------------------------------------------------------------
-- 5. 交互绑定
--------------------------------------------------------------------
toggleBtn.MouseButton1Click:Connect(function()
    STATE.Enabled = not STATE.Enabled
    refreshUI()
end)

autoBtn.MouseButton1Click:Connect(function()
    STATE.AutoAdjust = not STATE.AutoAdjust
    if STATE.AutoAdjust then
        smooth.precision = STATE.Precision
        smooth.range = STATE.Range
    end
    refreshUI()
end)

circleBtn.MouseButton1Click:Connect(function()
    STATE.ShowCircle = not STATE.ShowCircle
    refreshUI()
end)

-- 收起：把整个面板 ScreenGui 从 PlayerGui 移除
collapseBtn.MouseButton1Click:Connect(function()
    mainGui.Parent = nil
    floatBtn.Visible = true
end)

-- 展开：重新挂载面板 ScreenGui
makeDraggable(panel, titleBar)
makeDraggable(floatBtn, floatBtn, function()
    mainGui.Parent = PlayerGui
    floatBtn.Visible = false
end)

--------------------------------------------------------------------
-- 6. 脚下检测圈
--------------------------------------------------------------------
local circle = Instance.new("Part")
circle.Name = "BladeBallRangeCircle"
circle.Shape = Enum.PartType.Cylinder
circle.Anchored = true
circle.CanCollide = false
circle.CanQuery = false
circle.CanTouch = false
circle.CastShadow = false
circle.Material = Enum.Material.Neon
circle.Color = THEME.Accent
circle.Transparency = 1
circle.Size = Vector3.new(0.15, 2, 2)
circle.CFrame = CFrame.new(0, -500, 0)
circle.Parent = workspace

--------------------------------------------------------------------
-- 7. 核心逻辑
--------------------------------------------------------------------
local ballStates = setmetatable({}, { __mode = "k" })
local parried    = setmetatable({}, { __mode = "k" })

local function getRootPosition()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

local function getBalls()
    local folder = workspace:FindFirstChild("Balls")
    if not folder then return {} end
    local list = {}
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("BasePart") and child:GetAttribute("realBall") ~= false then
            list[#list + 1] = child
        end
    end
    return list
end

local function getRadius()
    return CONFIG.BaseRadius * STATE.Range
end

local function getTimeWindow()
    local t = (STATE.Precision - 1) / 99
    local window = CONFIG.BaseWindow + (CONFIG.MinWindow - CONFIG.BaseWindow) * t
    return math.max(CONFIG.WindowFloor, window)
end

local function fireParry()
    local now = os.clock()
    if now - STATE.LastParry < CONFIG.ParryCooldown then return end

    STATE.LastParry = now
    STATE.ParryCount += 1

    local humanDelay = CONFIG.HumanDelayMin
        + math.random() * (CONFIG.HumanDelayMax - CONFIG.HumanDelayMin)

    task.delay(humanDelay, function()
        if not STATE.Enabled then return end
        pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, 0)
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, 0)
        end)
    end)

    refreshUI()
end

local function updateBallStates(now)
    for _, ball in ipairs(getBalls()) do
        local st = ballStates[ball]
        if not st then
            ballStates[ball] = {
                lastPos = ball.Position,
                lastTime = now,
                speed = 0,
                velocity = Vector3.zero,
            }
        else
            local dt = now - st.lastTime
            if dt >= 0.02 then
                local move = ball.Position - st.lastPos
                st.velocity = move / dt
                st.speed = st.velocity.Magnitude
                st.lastPos = ball.Position
                st.lastTime = now
            end
        end
    end
end

local function applyAutoAdjust(now)
    if not STATE.AutoAdjust then return end
    local rootPos = getRootPosition()
    if not rootPos then return end

    local balls = getBalls()
    local bestEta, bestSpeed = math.huge, 0

    for _, ball in ipairs(balls) do
        local st = ballStates[ball]
        if st and st.speed > 2 then
            local dist = (ball.Position - rootPos).Magnitude
            if dist > 0.5 then
                local eta = dist / st.speed
                if eta < bestEta then
                    bestEta = eta
                    bestSpeed = st.speed
                end
            end
        end
    end

    if bestEta == math.huge then
        STATE.CurrentBallSpeed = 0
        return
    end
    STATE.CurrentBallSpeed = bestSpeed

    local targetRange = math.clamp(1 + bestSpeed / 35, 1, 10)
    local targetPrecision = math.clamp(100 - bestEta * 55, 5, CONFIG.PrecisionCap)

    smooth.range     = smooth.range     + (targetRange     - smooth.range)     * 0.1
    smooth.precision = smooth.precision + (targetPrecision - smooth.precision) * 0.1

    local r = math.clamp(math.floor(smooth.range + 0.5), 1, 10)
    local p = math.clamp(math.floor(smooth.precision + 0.5), 1, 100)

    if r ~= STATE.Range then
        STATE.Range = r
        rangeSlider.SetValue(r)
        if STATE.Enabled then refreshUI() end
    end
    if p ~= STATE.Precision then
        STATE.Precision = p
        precisionSlider.SetValue(p)
        if STATE.Enabled then refreshUI() end
    end
end

local function updateCircle(rootPos)
    if not rootPos or not STATE.Enabled or not STATE.ShowCircle then
        circle.Transparency = 1
        return
    end

    local radius = getRadius()
    circle.Size = Vector3.new(0.15, radius * 2, radius * 2)
    circle.CFrame = CFrame.new(rootPos - Vector3.new(0, CONFIG.CircleHeight, 0))
        * CFrame.Angles(0, 0, math.rad(90))

    local ratio = math.clamp(STATE.CurrentBallSpeed / 300, 0, 1)
    circle.Color = THEME.Accent:Lerp(THEME.Orange, ratio)
    circle.Transparency = CONFIG.CircleTrans
end

local function checkParry(rootPos)
    if not STATE.Enabled or not rootPos then return end

    local radius = getRadius()
    local window = getTimeWindow()
    local balls  = getBalls()

    for _, ball in ipairs(balls) do
        local st = ballStates[ball]
        if not st or st.speed < 1 then continue end

        local offset     = ball.Position - rootPos
        local horizontal = Vector3.new(offset.X, 0, offset.Z).Magnitude

        if horizontal > radius * 1.2 then
            parried[ball] = nil
            continue
        end

        if horizontal > radius then continue end
        if parried[ball] then continue end

        local toPlayer = (rootPos - ball.Position)
        if toPlayer.Magnitude < 0.1 then continue end
        local approaching = st.velocity:Dot(toPlayer.Unit) > 0
        if not approaching then continue end

        local eta = offset.Magnitude / st.speed
        if eta <= window then
            parried[ball] = true
            fireParry()
            break
        end
    end
end

--------------------------------------------------------------------
-- 8. 主循环
--------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    local now = os.clock()

    updateBallStates(now)
    applyAutoAdjust(now)

    local rootPos = getRootPosition()
    updateCircle(rootPos)
    checkParry(rootPos)
end)
