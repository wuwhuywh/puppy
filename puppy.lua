-- PuppyWare 精简版 + NPC 透视修复 + 子弹追踪 + FOV常显 + 加强队友检测 + 死亡检测 + 血条修复 + 大字体
local ok, err = pcall(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	task.wait(0.3)

	local Players = game:GetService("Players")
	local UIS = game:GetService("UserInputService")
	local RunService = game:GetService("RunService")
	local Workspace = game:GetService("Workspace")

	if not Players.LocalPlayer then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	end
	local LP = Players.LocalPlayer
	local Camera = Workspace.CurrentCamera

	local uiParent
	do
		local s, r = pcall(function() return gethui() end)
		if s and r then uiParent = r
		else
			local s2, r2 = pcall(function() return game:GetService("CoreGui") end)
			if s2 and r2 then uiParent = r2
			else uiParent = LP:WaitForChild("PlayerGui") end
		end
	end

	local lastPos = Vector2.new(0, 0)
	UIS.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			lastPos = Vector2.new(i.Position.X, i.Position.Y)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement then
			lastPos = Vector2.new(i.Position.X, i.Position.Y)
		end
	end)
	local function mousePos()
		if UIS.TouchEnabled and not UIS.MouseEnabled then return lastPos end
		return UIS:GetMouseLocation()
	end

	local accent = Color3.fromRGB(255, 120, 30)
	local conns = {}
	local function conn(sig, fn)
		local c = sig:Connect(fn)
		conns[#conns + 1] = c
		return c
	end
	local function mk(class, props)
		local o = Instance.new(class)
		if props then
			for k, v in pairs(props) do o[k] = v end
		end
		return o
	end

	local HasDrawing = false
	pcall(function()
		local t = Drawing.new("Square")
		HasDrawing = true
		t:Remove()
	end)

	local cfg = {
		ESP = false, Boxes = true, Skeletons = false, Names = true, Health = false, Distance = true,
		RenderDist = 2500, TeamCheck = true, TeamColors = false,
		ShowNPC = true,
		BoxColor = Color3.fromRGB(0, 186, 186), OutlineColor = Color3.fromRGB(15, 15, 15),
		NameColor = Color3.fromRGB(255, 255, 255), DistanceColor = Color3.fromRGB(180, 180, 180),
		Chams = false, ChamsColor = Color3.fromRGB(100, 120, 255), EnemyLight = false,
		NoRecoil = false,
		BulletTrack = false,
		AimPart = "Head",
		AimFov = 300,
		AimFovDraw = true,
		AimTeamCheck = true
	}

	-- ===== 加强版队伍检测 =====
	local function getTeam(p)
		if not p then return nil end
		local ok1, team = pcall(function() return p.Team end)
		if ok1 and team then
			local name = team.Name
			if name and name ~= "" then return name end
		end
		for _, attrName in ipairs({"Team", "TeamId", "TeamName", "CurrentTeam", "Side"}) do
			local ok2, attr = pcall(function() return p:GetAttribute(attrName) end)
			if ok2 and attr ~= nil then
				local s = tostring(attr)
				if s ~= "" then return s end
			end
		end
		for _, child in ipairs(p:GetChildren()) do
			if child.Name == "Team" or child.Name == "TeamId" or child.Name == "TeamName" then
				if child:IsA("StringValue") and tostring(child.Value) ~= "" then
					return tostring(child.Value)
				elseif child:IsA("IntValue") then
					return tostring(child.Value)
				end
			end
		end
		local char = p.Character
		if char then
			local parentName = char.Parent and char.Parent.Name
			if parentName == "Terrorists" or parentName == "Counter-Terrorists" then
				return parentName
			end
			for _, attrName in ipairs({"Team", "TeamId", "TeamName"}) do
				local ok3, attr = pcall(function() return char:GetAttribute(attrName) end)
				if ok3 and attr ~= nil then
					local s = tostring(attr)
					if s ~= "" then return s end
				end
			end
		end
		return nil
	end

	local function getTeamColor(p)
		if not p then return nil end
		local ok, color = pcall(function() return p.TeamColor end)
		if ok and color then return color end
		return nil
	end

	local teamColor = {
		["Terrorists"] = Color3.fromRGB(204, 170, 80),
		["Counter-Terrorists"] = Color3.fromRGB(100, 149, 200)
	}

	-- ===== NPC 集合 + 工具 =====
	local npcSet = {}

	local function findRoot(model)
		if not model then return nil end
		for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
			local p = model:FindFirstChild(name)
			if p and p:IsA("BasePart") then return p end
		end
		if model.PrimaryPart and model.PrimaryPart:IsA("BasePart") then
			return model.PrimaryPart
		end
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.95 then
				return d
			end
		end
		return nil
	end

	-- ===== NPC 识别（宽松版） =====
	local NPC_NAME_KEYS = {"bot", "npc", "dummy", "enemy", "soldier", "guard", "hostage", "ai_", "_ai", "monster"}
	local function isHumanoidModel(model)
		if not model or not model:IsA("Model") then return false end
		if model == LP.Character then return false end
		if Players:GetPlayerFromCharacter(model) then return false end
		local parentName = model.Parent and model.Parent.Name
		if parentName == "Debris" or parentName == "Cameras" then return false end

		-- 1. 有 Humanoid 就是 NPC
		if model:FindFirstChildOfClass("Humanoid") then return true end

		-- 2. 有 Head + 至少 2 个 BasePart（排除单部件装饰）
		local head = model:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			local parts = 0
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("BasePart") then
					parts = parts + 1
					if parts >= 2 then return true end
				end
			end
		end

		-- 3. 名字匹配关键词 + 有至少一个 BasePart
		local lower = string.lower(model.Name)
		for _, key in ipairs(NPC_NAME_KEYS) do
			if string.find(lower, key, 1, true) then
				if model:FindFirstChildWhichIsA("BasePart") then return true end
				break
			end
		end

		return false
	end

	-- ===== 死亡检测 =====
	local function isTargetAlive(targetPart)
		if not targetPart or not targetPart.Parent then return false end
		local model = targetPart:FindFirstAncestorOfClass("Model")
		if not model or not model.Parent then return false end
		if model:GetAttribute("Dead") == true then return false end
		if model:GetAttribute("Knocked") == true then return false end
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			if hum.Health <= 0 then return false end
			if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
		end
		return true
	end

	-- ===== 菜单 =====
	local ScreenGui = Instance.new("ScreenGui")
	ScreenGui.Name = "PuppyLite"
	ScreenGui.DisplayOrder = 9999
	ScreenGui.IgnoreGuiInset = true
	ScreenGui.ResetOnSpawn = false
	ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	local s1 = pcall(function() ScreenGui.Parent = uiParent end)
	if not s1 then ScreenGui.Parent = LP:WaitForChild("PlayerGui") end

	local scale = Instance.new("UIScale")
	scale.Parent = ScreenGui
	local function updateScale()
		local vp = Camera and Camera.ViewportSize or Vector2.new(800, 600)
		scale.Scale = math.clamp(math.min(vp.X / 720, vp.Y / 620), 0.45, 1.25)
	end
	updateScale()
	task.spawn(function() while task.wait(1) do updateScale() end end)

	local main = mk("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BorderColor3 = Color3.fromRGB(60, 60, 60), BorderSizePixel = 1,
		Parent = ScreenGui, Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 660, 0, 560)
	})
	local tabs = mk("Frame", {
		BackgroundColor3 = Color3.fromRGB(15, 15, 15), BorderSizePixel = 0,
		Parent = main, Position = UDim2.new(0, 1, 0, 1), Size = UDim2.new(0, 76, 1, -2)
	})
	local pagesHolder = mk("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 20, 20), BorderSizePixel = 0,
		Parent = main, Position = UDim2.new(0, 77, 0, 1), Size = UDim2.new(1, -78, 1, -2)
	})
	mk("UIListLayout", {Parent = tabs, Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})
	mk("UIPadding", {Parent = tabs, PaddingTop = UDim.new(0, 10)})

	local pages = {}
	local function createPage(label)
		local btn = mk("TextButton", {
			BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0,
			Font = Enum.Font.Code, Text = label, TextColor3 = Color3.fromRGB(150, 150, 150),
			TextSize = 13, Parent = tabs, Size = UDim2.new(0, 60, 0, 48), TextWrapped = true
		})
		local page = mk("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Parent = pagesHolder,
			Size = UDim2.new(1, 0, 1, 0), Visible = false, ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0)
		})
		mk("UIListLayout", {Parent = page, Padding = UDim.new(0, 10),
			HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder})
		mk("UIPadding", {Parent = page, PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)})
		local p = {Btn = btn, Frame = page, Active = false}
		function p:setActive(state)
			self.Active = state
			page.Visible = state
			btn.BackgroundColor3 = state and Color3.fromRGB(45, 45, 45) or Color3.fromRGB(30, 30, 30)
			btn.TextColor3 = state and accent or Color3.fromRGB(150, 150, 150)
		end
		conn(btn.MouseButton1Click, function()
			for _, other in ipairs(pages) do
				if other ~= p and other.Active then other:setActive(false) end
			end
			p:setActive(true)
		end)
		pages[#pages + 1] = p
		if #pages == 1 then p:setActive(true) end
		return p
	end

	local function createSection(page, title, height)
		local holder = mk("Frame", {
			BackgroundColor3 = Color3.fromRGB(30, 30, 30), BorderSizePixel = 0,
			Parent = page.Frame, Size = UDim2.new(1, -20, 0, height or 150)
		})
		mk("TextLabel", {
			BackgroundTransparency = 1, Parent = holder, Position = UDim2.new(0, 8, 0, 3),
			Size = UDim2.new(1, -16, 0, 20), Font = Enum.Font.Code, Text = title,
			TextColor3 = Color3.fromRGB(210, 210, 210), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
		})
		local content = mk("ScrollingFrame", {
			BackgroundTransparency = 1, BorderSizePixel = 0, Parent = holder,
			Position = UDim2.new(0, 0, 0, 26), Size = UDim2.new(1, 0, 1, -26),
			ScrollBarThickness = 4, ScrollBarImageColor3 = Color3.fromRGB(80, 80, 80),
			AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
			CanvasSize = UDim2.new(0, 0, 0, 0)
		})
		mk("UIListLayout", {Parent = content, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
		mk("UIPadding", {Parent = content, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6)})
		return {Content = content, Frame = holder}
	end

	local function createToggle(section, name, default, cb)
		local row = mk("Frame", {BackgroundTransparency = 1, Parent = section.Content, Size = UDim2.new(1, 0, 0, 30)})
		mk("TextLabel", {
			BackgroundTransparency = 1, Parent = row, Position = UDim2.new(0, 4, 0, 0),
			Size = UDim2.new(1, -56, 1, 0), Font = Enum.Font.Code, Text = name,
			TextColor3 = Color3.fromRGB(205, 205, 205), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
		})
		local box = mk("Frame", {
			BackgroundColor3 = Color3.fromRGB(60, 60, 60), Parent = row,
			Position = UDim2.new(1, -38, 0, 6), Size = UDim2.new(0, 28, 0, 18)
		})
		local btn = mk("TextButton", {BackgroundTransparency = 1, Text = "", Parent = row, Size = UDim2.new(1, 0, 1, 0)})
		local state = default
		local function apply(v)
			state = v
			box.BackgroundColor3 = v and accent or Color3.fromRGB(60, 60, 60)
			cb(v)
		end
		conn(btn.MouseButton1Click, function() apply(not state) end)
		apply(state)
		return {Get = function() return state end, Set = apply}
	end

	local function createSlider(section, name, default, minv, maxv, cb)
		local row = mk("Frame", {BackgroundTransparency = 1, Parent = section.Content, Size = UDim2.new(1, 0, 0, 46)})
		mk("TextLabel", {
			BackgroundTransparency = 1, Parent = row, Position = UDim2.new(0, 4, 0, 0),
			Size = UDim2.new(1, -70, 0, 20), Font = Enum.Font.Code, Text = name,
			TextColor3 = Color3.fromRGB(205, 205, 205), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
		})
		local barBg = mk("Frame", {
			BackgroundColor3 = Color3.fromRGB(60, 60, 60), Parent = row,
			Position = UDim2.new(0, 4, 0, 28), Size = UDim2.new(1, -70, 0, 8)
		})
		local fill = mk("Frame", {BackgroundColor3 = accent, Parent = barBg, Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0})
		local valLabel = mk("TextLabel", {
			BackgroundTransparency = 1, Parent = row, Position = UDim2.new(1, -60, 0, 0),
			Size = UDim2.new(0, 56, 0, 20), Font = Enum.Font.Code, Text = tostring(default),
			TextColor3 = Color3.fromRGB(190, 190, 190), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right
		})
		local btn = mk("TextButton", {BackgroundTransparency = 1, Text = "", Parent = barBg, Size = UDim2.new(1, 0, 1, 0)})
		local state = default
		local holding = false
		local function apply(v)
			state = math.clamp(v, minv, maxv)
			fill.Size = UDim2.new((state - minv) / (maxv - minv), 0, 1, 0)
			valLabel.Text = tostring(math.floor(state * 100) / 100)
			cb(state)
		end
		local function refresh()
			local m = mousePos()
			local rel = math.clamp((m.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X, 0, 1)
			apply(minv + (maxv - minv) * rel)
		end
		conn(btn.MouseButton1Down, function()
			holding = true
			section.Content.ScrollingEnabled = false
			refresh()
		end)
		conn(UIS.InputChanged, function(i)
			if holding and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				refresh()
			end
		end)
		conn(UIS.InputEnded, function(i)
			if holding and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
				holding = false
				section.Content.ScrollingEnabled = true
			end
		end)
		apply(state)
		return {Get = function() return state end, Set = apply}
	end

	local presetColors = {
		Color3.fromRGB(0, 186, 186), Color3.fromRGB(255, 80, 80), Color3.fromRGB(80, 255, 120),
		Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 180, 60), Color3.fromRGB(180, 120, 255),
		Color3.fromRGB(120, 180, 255), Color3.fromRGB(255, 255, 0), Color3.fromRGB(255, 0, 255),
		Color3.fromRGB(20, 20, 20)
	}
	local function createColor(section, name, default, cb)
		local row = mk("Frame", {BackgroundTransparency = 1, Parent = section.Content, Size = UDim2.new(1, 0, 0, 30)})
		mk("TextLabel", {
			BackgroundTransparency = 1, Parent = row, Position = UDim2.new(0, 4, 0, 0),
			Size = UDim2.new(1, -56, 1, 0), Font = Enum.Font.Code, Text = name,
			TextColor3 = Color3.fromRGB(205, 205, 205), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
		})
		local swatch = mk("Frame", {BackgroundColor3 = default, Parent = row,
			Position = UDim2.new(1, -38, 0, 6), Size = UDim2.new(0, 28, 0, 18), BorderSizePixel = 0})
		local btn = mk("TextButton", {BackgroundTransparency = 1, Text = "", Parent = row, Size = UDim2.new(1, 0, 1, 0)})
		local color = default
		local function apply(c)
			color = c
			swatch.BackgroundColor3 = c
			cb(c)
		end
		conn(btn.MouseButton1Click, function()
			local best, bestD = 1, math.huge
			for i, c in ipairs(presetColors) do
				local d = (c.R - color.R) ^ 2 + (c.G - color.G) ^ 2 + (c.B - color.B) ^ 2
				if d < bestD then bestD = d; best = i end
			end
			apply(presetColors[(best % #presetColors) + 1])
		end)
		apply(color)
		return {Get = function() return color end}
	end

	local function createCycle(section, name, options, defaultIndex, cb)
		local row = mk("Frame", {BackgroundTransparency = 1, Parent = section.Content, Size = UDim2.new(1, 0, 0, 30)})
		mk("TextLabel", {
			BackgroundTransparency = 1, Parent = row, Position = UDim2.new(0, 4, 0, 0),
			Size = UDim2.new(1, -140, 1, 0), Font = Enum.Font.Code, Text = name,
			TextColor3 = Color3.fromRGB(205, 205, 205), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left
		})
		local valLabel = mk("TextLabel", {
			BackgroundTransparency = 1, Parent = row, Position = UDim2.new(1, -130, 0, 0),
			Size = UDim2.new(0, 122, 1, 0), Font = Enum.Font.Code, Text = tostring(options[defaultIndex or 1]),
			TextColor3 = accent, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Right
		})
		local btn = mk("TextButton", {BackgroundTransparency = 1, Text = "", Parent = row, Size = UDim2.new(1, 0, 1, 0)})
		local idx = defaultIndex or 1
		local function apply(i)
			idx = i
			valLabel.Text = tostring(options[i])
			cb(options[i], i)
		end
		conn(btn.MouseButton1Click, function()
			apply((idx % #options) + 1)
		end)
		apply(idx)
		return {Get = function() return options[idx] end}
	end

	-- ===== 悬浮按钮 + 状态标签 =====
	local mobileGui = Instance.new("ScreenGui")
	mobileGui.Name = "PuppyLiteToggle"
	mobileGui.DisplayOrder = 10000
	mobileGui.IgnoreGuiInset = true
	mobileGui.ResetOnSpawn = false
	local s2 = pcall(function() mobileGui.Parent = uiParent end)
	if not s2 then mobileGui.Parent = LP:WaitForChild("PlayerGui") end

	local toggleBtn = mk("TextButton", {
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(20, 20, 20),
		BackgroundTransparency = 0.1, BorderColor3 = accent, BorderSizePixel = 1,
		AutoButtonColor = false, Font = Enum.Font.GothamBold, Parent = mobileGui,
		Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(0, 64, 0, 64),
		Text = "P", TextColor3 = Color3.fromRGB(255, 255, 255), TextSize = 24
	})
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = toggleBtn

	-- 子弹追踪状态
	local aimStatus = mk("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Font = Enum.Font.Code, Parent = mobileGui,
		Position = UDim2.new(0, 88, 0.5, -16), Size = UDim2.new(0, 180, 0, 24),
		Text = "", TextColor3 = Color3.fromRGB(255, 200, 80),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false
	})

	-- NPC 计数
	local npcStatus = mk("TextLabel", {
		AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 0.35, BorderSizePixel = 0,
		Font = Enum.Font.Code, Parent = mobileGui,
		Position = UDim2.new(0, 88, 0.5, 16), Size = UDim2.new(0, 180, 0, 24),
		Text = "NPC: 0", TextColor3 = Color3.fromRGB(180, 180, 255),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false
	})

	local dragStart, startPos, moved
	conn(toggleBtn.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = i.Position
			startPos = toggleBtn.Position
			moved = false
		end
	end)
	conn(UIS.InputChanged, function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseMovement) then
			local d = i.Position - dragStart
			if d.Magnitude > 8 then moved = true end
			if moved then
				toggleBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end)
	conn(UIS.InputEnded, function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1) then
			if not moved then
				ScreenGui.Enabled = not ScreenGui.Enabled
			end
			dragStart = nil
		end
	end)

	ScreenGui.Enabled = false

	local combat = createPage("战斗")
	local visual = createPage("视觉")

	local aimSec = createSection(combat, "子弹追踪", 350)
	createToggle(aimSec, "启用子弹追踪", cfg.BulletTrack, function(v) cfg.BulletTrack = v end)
	createCycle(aimSec, "瞄准部位", {"Head", "UpperTorso", "HumanoidRootPart"}, 1, function(v) cfg.AimPart = v end)
	createSlider(aimSec, "FOV 范围", cfg.AimFov, 40, 800, function(v) cfg.AimFov = v end)
	createToggle(aimSec, "团队检测(玩家)", cfg.AimTeamCheck, function(v) cfg.AimTeamCheck = v end)
	createToggle(aimSec, "显示锁定圈", cfg.AimFovDraw, function(v) cfg.AimFovDraw = v end)

	local cSec = createSection(combat, "武器", 110)
	createToggle(cSec, "无后坐", cfg.NoRecoil, function(v) cfg.NoRecoil = v end)

	local espSec = createSection(visual, "玩家 ESP", 420)
	createToggle(espSec, "ESP(玩家)", cfg.ESP, function(v) cfg.ESP = v end)
	createToggle(espSec, "显示人机/NPC", cfg.ShowNPC, function(v) cfg.ShowNPC = v end)
	createToggle(espSec, "方框", cfg.Boxes, function(v) cfg.Boxes = v end)
	createToggle(espSec, "骨骼", cfg.Skeletons, function(v) cfg.Skeletons = v end)
	createToggle(espSec, "名字", cfg.Names, function(v) cfg.Names = v end)
	createToggle(espSec, "血量", cfg.Health, function(v) cfg.Health = v end)
	createToggle(espSec, "距离", cfg.Distance, function(v) cfg.Distance = v end)
	createToggle(espSec, "团队检测(玩家)", cfg.TeamCheck, function(v) cfg.TeamCheck = v end)
	createSlider(espSec, "渲染距离", cfg.RenderDist, 100, 5000, function(v) cfg.RenderDist = v end)

	local colorSec = createSection(visual, "颜色", 240)
	createColor(colorSec, "方框颜色", cfg.BoxColor, function(v) cfg.BoxColor = v end)
	createColor(colorSec, "描边颜色", cfg.OutlineColor, function(v) cfg.OutlineColor = v end)
	createColor(colorSec, "名字颜色", cfg.NameColor, function(v) cfg.NameColor = v end)
	createColor(colorSec, "距离颜色", cfg.DistanceColor, function(v) cfg.DistanceColor = v end)
	createToggle(colorSec, "团队颜色", cfg.TeamColors, function(v) cfg.TeamColors = v end)

	local chamSec = createSection(visual, "模型", 180)
	createToggle(chamSec, "Chams 透视", cfg.Chams, function(v) cfg.Chams = v end)
	createColor(chamSec, "Chams 颜色", cfg.ChamsColor, function(v) cfg.ChamsColor = v end)
	createToggle(chamSec, "敌人灯光", cfg.EnemyLight, function(v) cfg.EnemyLight = v end)

	-- ===== FOV 圈 + 目标锁定圈 =====
	local currentTarget = nil

	local fovCircle
	local lockCircle
	if HasDrawing then
		pcall(function()
			fovCircle = Drawing.new("Circle")
			fovCircle.Filled = false
			fovCircle.Thickness = 1
			fovCircle.NumSides = 64
			fovCircle.Color = Color3.fromRGB(80, 255, 120)
			fovCircle.Visible = false
		end)
		pcall(function()
			lockCircle = Drawing.new("Circle")
			lockCircle.Filled = false
			lockCircle.Thickness = 2
			lockCircle.NumSides = 32
			lockCircle.Color = Color3.fromRGB(80, 255, 120)
			lockCircle.Visible = false
		end)
	end

	local function findBestTarget()
		if not cfg.BulletTrack or not Camera then return nil end
		local myTeam = getTeam(LP)
		local myColor = getTeamColor(LP)
		local center = Camera.ViewportSize / 2
		local best, bestDist = nil, math.huge

		for _, p in ipairs(Players:GetPlayers()) do
			if p == LP then continue end
			local char = p.Character
			if not char or not char.Parent then continue end
			if char:GetAttribute("Dead") == true then continue end
			if char:GetAttribute("Knocked") == true then continue end
			local hum = char:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 then continue end
			if hum:GetState() == Enum.HumanoidStateType.Dead then continue end

			if cfg.AimTeamCheck then
				local pTeam = getTeam(p)
				local pColor = getTeamColor(p)
				if myTeam and pTeam and myTeam == pTeam then continue end
				if myColor and pColor and myColor == pColor then continue end
			end

			local targetPart = char:FindFirstChild(cfg.AimPart)
				or char:FindFirstChild("Head")
				or char:FindFirstChild("HumanoidRootPart")
			if not targetPart or not isTargetAlive(targetPart) then continue end
			local sp, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
			if sp.Z > 0 and onScreen then
				local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
				if d <= cfg.AimFov and d < bestDist then
					bestDist = d
					best = targetPart
				end
			end
		end

		for model in pairs(npcSet) do
			if not model.Parent then continue end
			if model:GetAttribute("Dead") == true then continue end
			if model:GetAttribute("Knocked") == true then continue end
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and (hum.Health <= 0 or hum:GetState() == Enum.HumanoidStateType.Dead) then continue end
			local targetPart = model:FindFirstChild(cfg.AimPart)
				or model:FindFirstChild("Head")
				or findRoot(model)
			if not targetPart or not targetPart:IsA("BasePart") or not isTargetAlive(targetPart) then continue end
			local sp, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
			if sp.Z > 0 and onScreen then
				local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
				if d <= cfg.AimFov and d < bestDist then
					bestDist = d
					best = targetPart
				end
			end
		end

		return best
	end

	RunService:BindToRenderStep("PuppyBulletTarget", Enum.RenderPriority.Last.Value, function(dt)
		Camera = Workspace.CurrentCamera
		if not Camera then
			currentTarget = nil
			if fovCircle then fovCircle.Visible = false end
			if lockCircle then lockCircle.Visible = false end
			aimStatus.Visible = false
			return
		end

		if currentTarget and not isTargetAlive(currentTarget) then
			currentTarget = nil
		end

		currentTarget = findBestTarget()

		-- FOV 圈常显
		if fovCircle then
			fovCircle.Visible = cfg.BulletTrack and cfg.AimFovDraw
			if fovCircle.Visible then
				fovCircle.Position = Camera.ViewportSize / 2
				fovCircle.Radius = cfg.AimFov
				fovCircle.Color = Color3.fromRGB(80, 255, 120)
				fovCircle.Thickness = 1
			end
		end

		-- 锁定圈只在锁定时显示
		if lockCircle then
			if cfg.BulletTrack and cfg.AimFovDraw and currentTarget and currentTarget.Parent and isTargetAlive(currentTarget) then
				local sp, onScreen = Camera:WorldToViewportPoint(currentTarget.Position)
				if sp.Z > 0 and onScreen then
					local dist = (Camera.CFrame.Position - currentTarget.Position).Magnitude
					lockCircle.Visible = true
					lockCircle.Position = Vector2.new(sp.X, sp.Y)
					lockCircle.Radius = math.clamp(180 / math.max(dist, 1), 14, 70)
					lockCircle.Color = Color3.fromRGB(80, 255, 120)
					lockCircle.Thickness = 2
				else
					lockCircle.Visible = false
				end
			else
				lockCircle.Visible = false
			end
		end

		aimStatus.Visible = cfg.BulletTrack
		if aimStatus.Visible then
			if currentTarget and isTargetAlive(currentTarget) then
				aimStatus.Text = "锁定: " .. tostring(currentTarget.Parent and currentTarget.Parent.Name or "?")
				aimStatus.TextColor3 = Color3.fromRGB(80, 255, 120)
			else
				aimStatus.Text = "搜索中..."
				aimStatus.TextColor3 = Color3.fromRGB(255, 200, 80)
			end
		end
	end)

	-- ===== 子弹追踪 hook =====
	task.spawn(function()
		if typeof(hookfunction) ~= "function" or typeof(getgc) ~= "function" then
			warn("[Puppy] 执行器不支持 hookfunction/getgc，子弹追踪不可用")
			return
		end

		local bulletClass = nil
		for attempt = 1, 45 do
			for _, obj in next, getgc(true) do
				if type(obj) == "table"
					and typeof(rawget(obj, "_performRaycast")) == "function"
					and rawget(obj, "getTrueSpread") ~= nil then
					bulletClass = obj
					break
				end
			end
			if bulletClass then break end
			task.wait(0.5)
		end

		if not bulletClass then
			warn("[Puppy] 未找到子弹类，当前游戏可能不支持子弹追踪")
			return
		end

		local hookImpl
		local oldRaycast
		hookImpl = function(...)
			local returns = table.pack(oldRaycast(...))
			local result = returns[1]
			if type(result) ~= "table" then
				return table.unpack(returns, 1, returns.n)
			end

			if cfg.BulletTrack and currentTarget and currentTarget.Parent and isTargetAlive(currentTarget) then
				pcall(function()
					local hits = rawget(result, "Hits")
					local origin = rawget(result, "Origin")
					if type(hits) ~= "table" or typeof(origin) ~= "Vector3" then return end

					local lastIndex = nil
					for index, hit in pairs(hits) do
						if type(hit) == "table" then
							if lastIndex == nil or index > lastIndex then lastIndex = index end
						end
					end
					local finalHit = lastIndex and hits[lastIndex]
					if type(finalHit) ~= "table" then return end

					local aimPos = currentTarget.Position
					finalHit.Instance = currentTarget
					finalHit.Position = aimPos
					if finalHit.Exit ~= nil then finalHit.Exit = false end

					local delta = aimPos - origin
					local length = delta.Magnitude
					if length > 0.001 then
						result.Distance = length
						result.Direction = delta.Unit
						local unit = delta.Unit
						for index, hit in pairs(hits) do
							if index ~= lastIndex and type(hit) == "table" and typeof(hit.Position) == "Vector3" then
								local along = (hit.Position - origin):Dot(unit)
								if along > length then
									hit.Position = origin + unit * (length * 0.5)
								end
							end
						end
					end
				end)
			end

			return table.unpack(returns, 1, returns.n)
		end

		local okHook = pcall(function()
			oldRaycast = hookfunction(bulletClass._performRaycast, hookImpl)
		end)

		if not okHook or not oldRaycast then
			oldRaycast = bulletClass._performRaycast
			bulletClass._performRaycast = hookImpl
		end
	end)

	-- ===== ESP =====
	local espData = {}
	local BONES_R15 = {
		{"Head","UpperTorso"},{"UpperTorso","LowerTorso"},
		{"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
		{"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
		{"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
		{"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"}
	}
	local BONES_R6 = {
		{"Head","Torso"},{"Torso","Left Arm"},{"Torso","Right Arm"},{"Torso","Left Leg"},{"Torso","Right Leg"}
	}

	local function createESP(key)
		if not HasDrawing or espData[key] then return end
		local s, o = pcall(function()
			local o = {
				Box = Drawing.new("Square"), BoxOutline = Drawing.new("Square"),
				Name = Drawing.new("Text"), Distance = Drawing.new("Text"),
				HealthBg = Drawing.new("Square"), Health = Drawing.new("Square"),
				Bones = {}
			}
			o.BoxOutline.Thickness = 2
			o.BoxOutline.Filled = false
			o.BoxOutline.Transparency = 0
			o.BoxOutline.Color = cfg.OutlineColor
			o.Box.Thickness = 1
			o.Box.Filled = false
			o.Box.Transparency = 0
			o.Box.Color = cfg.BoxColor
			o.Name.Center = true
			o.Name.Outline = true
			o.Name.Font = 1
			o.Name.Size = 15
			o.Distance.Center = true
			o.Distance.Outline = true
			o.Distance.Font = 1
			o.Distance.Size = 14
			o.HealthBg.Filled = true
			o.HealthBg.Thickness = 1
			o.HealthBg.Transparency = 0
			o.HealthBg.Color = Color3.fromRGB(15, 15, 15)
			o.Health.Filled = true
			o.Health.Thickness = 1
			o.Health.Transparency = 0
			o.Health.Color = Color3.fromRGB(50, 205, 50)
			for i = 1, 15 do
				local l = Drawing.new("Line")
				l.Thickness = 1
				l.Transparency = 0
				l.Visible = false
				table.insert(o.Bones, l)
			end
			return o
		end)
		if s and o then espData[key] = o end
	end

	local function removeESP(key)
		local o = espData[key]
		if not o then return end
		pcall(function()
			for _, v in pairs(o) do
				if type(v) == "table" then
					for _, b in pairs(v) do b:Remove() end
				else
					v:Remove()
				end
			end
		end)
		espData[key] = nil
	end

	local function hideESP(key)
		local data = espData[key]
		if not data then return end
		for _, v in pairs(data) do
			if type(v) ~= "table" and v then
				pcall(function() v.Visible = false end)
			end
		end
		for _, b in pairs(data.Bones or {}) do
			if b then pcall(function() b.Visible = false end) end
		end
	end

	local function cleanExtras(model)
		if not model then return end
		local hl = model:FindFirstChild("PuppyChams")
		if hl then hl:Destroy() end
		local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
		local light = root and root:FindFirstChild("PuppyLight")
		if light then light:Destroy() end
	end

	-- 三维定位：findRoot → GetPivot → GetBoundingBox 三重兜底
	local function getModelPosition(model)
		if not model then return nil end
		local root = findRoot(model)
		if root and root:IsA("BasePart") then return root.Position end
		local okp, cf = pcall(function() return model:GetPivot() end)
		if okp and cf then return cf.Position end
		local okb, cf2 = pcall(function() return model:GetBoundingBox() end)
		if okb and cf2 then return cf2.Position end
		return nil
	end

	local function renderESP(key, model, hum, root, displayName, entityTeam, enabled)
		if not enabled or not model then
			hideESP(key)
			cleanExtras(model)
			return
		end

		local rootPos3D = getModelPosition(model)
		if not rootPos3D then
			hideESP(key)
			cleanExtras(model)
			return
		end

		if model:GetAttribute("Dead") == true then
			hideESP(key)
			cleanExtras(model)
			return
		end
		if hum and hum.Health <= 0 then
			hideESP(key)
			cleanExtras(model)
			return
		end

		local camPos = Camera.CFrame.Position
		if (camPos - rootPos3D).Magnitude > cfg.RenderDist then
			hideESP(key)
			cleanExtras(model)
			return
		end

		local data = espData[key]
		if not data then
			createESP(key)
			data = espData[key]
			if not data then return end
		end

		if cfg.Chams then
			local hl = model:FindFirstChild("PuppyChams")
			if not hl then
				hl = Instance.new("Highlight")
				hl.Name = "PuppyChams"
				hl.Adornee = model
				hl.FillTransparency = 0.25
				hl.OutlineTransparency = 0
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.Parent = model
			end
			hl.FillColor = cfg.ChamsColor
			hl.OutlineColor = cfg.ChamsColor
		else
			local hl = model:FindFirstChild("PuppyChams")
			if hl then hl:Destroy() end
		end

		local lightHost = (root and root:IsA("BasePart")) and root or model.PrimaryPart or model:FindFirstChild("Head")
		if cfg.EnemyLight and lightHost and lightHost:IsA("BasePart") then
			if not lightHost:FindFirstChild("PuppyLight") then
				local l = Instance.new("PointLight")
				l.Name = "PuppyLight"
				l.Color = Color3.fromRGB(130, 150, 255)
				l.Range = 10
				l.Brightness = 2
				l.Shadows = false
				l.Parent = lightHost
			end
		elseif lightHost and lightHost:IsA("BasePart") then
			local l = lightHost:FindFirstChild("PuppyLight")
			if l then l:Destroy() end
		end

		local rootScreenPos = Camera:WorldToViewportPoint(rootPos3D)
		if rootScreenPos.Z <= 0 then
			hideESP(key)
			return
		end
		local vp = Camera.ViewportSize
		local margin = 300
		if rootScreenPos.X < -margin or rootScreenPos.X > vp.X + margin
			or rootScreenPos.Y < -margin or rootScreenPos.Y > vp.Y + margin then
			hideESP(key)
			return
		end

		local color = cfg.BoxColor
		if cfg.TeamColors and entityTeam and teamColor[entityTeam] then
			color = teamColor[entityTeam]
		end

		local head = model:FindFirstChild("Head")
		local headScreen, legScreen
		if head and head:IsA("BasePart") then
			headScreen = Camera:WorldToViewportPoint(head.Position)
			legScreen = Camera:WorldToViewportPoint(rootPos3D - Vector3.new(0, 3, 0))
		else
			local okb, cf, sz = pcall(function() return model:GetBoundingBox() end)
			if okb and cf and sz then
				headScreen = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, sz.Y / 2, 0))
				legScreen = Camera:WorldToViewportPoint(cf.Position - Vector3.new(0, sz.Y / 2, 0))
			else
				headScreen = Camera:WorldToViewportPoint(rootPos3D + Vector3.new(0, 2, 0))
				legScreen = Camera:WorldToViewportPoint(rootPos3D - Vector3.new(0, 3, 0))
			end
		end
		if headScreen.Z <= 0 or legScreen.Z <= 0 then
			hideESP(key)
			return
		end

		local h = math.max(math.abs(headScreen.Y - legScreen.Y), 4)
		local w = h / 1.6
		local x = rootScreenPos.X - w / 2
		local y = headScreen.Y

		data.Box.Visible = cfg.Boxes
		data.BoxOutline.Visible = cfg.Boxes
		if cfg.Boxes then
			local size = Vector2.new(w, h)
			local pos = Vector2.new(x, y)
			data.Box.Size = size
			data.Box.Position = pos
			data.Box.Color = color
			data.Box.Transparency = 0
			data.BoxOutline.Size = size
			data.BoxOutline.Position = pos
			data.BoxOutline.Color = cfg.OutlineColor
			data.BoxOutline.Transparency = 0
		end

		local isR15 = model:FindFirstChild("UpperTorso") ~= nil
		local bones = isR15 and BONES_R15 or BONES_R6
		for i, line in ipairs(data.Bones) do
			local b = bones[i]
			if cfg.Skeletons and b then
				local a1 = model:FindFirstChild(b[1])
				local a2 = model:FindFirstChild(b[2])
				if a1 and a2 then
					local p1 = Camera:WorldToViewportPoint(a1.Position)
					local p2 = Camera:WorldToViewportPoint(a2.Position)
					if p1.Z > 0 and p2.Z > 0 then
						line.From = Vector2.new(p1.X, p1.Y)
						line.To = Vector2.new(p2.X, p2.Y)
						line.Color = color
						line.Visible = true
					else
						line.Visible = false
					end
				else
					line.Visible = false
				end
			else
				line.Visible = false
			end
		end

		if cfg.Names then
			data.Name.Text = displayName
			data.Name.Position = Vector2.new(rootScreenPos.X, y - 18)
			data.Name.Color = cfg.NameColor
			data.Name.Visible = true
		else
			data.Name.Visible = false
		end

		if cfg.Distance then
			data.Distance.Text = tostring(math.floor((camPos - rootPos3D).Magnitude)) .. "m"
			data.Distance.Position = Vector2.new(rootScreenPos.X, y + h + 2)
			data.Distance.Color = cfg.DistanceColor
			data.Distance.Visible = true
		else
			data.Distance.Visible = false
		end

		if cfg.Health and hum then
			local maxHP = hum.MaxHealth
			if not maxHP or maxHP <= 0 then maxHP = 100 end
			local curHP = hum.Health or 0
			local pct = math.clamp(curHP / maxHP, 0, 1)

			local bw = 6
			local bh = math.max(h, 4)
			local hh = math.max(bh * pct, 1)
			local bx = x - 10
			local by = y

			data.HealthBg.Filled = true
			data.HealthBg.Thickness = 1
			data.HealthBg.Transparency = 0
			data.HealthBg.Color = Color3.fromRGB(10, 10, 10)
			data.HealthBg.Position = Vector2.new(bx - 1, by - 1)
			data.HealthBg.Size = Vector2.new(bw + 2, bh + 2)
			data.HealthBg.Visible = true

			data.Health.Filled = true
			data.Health.Thickness = 1
			data.Health.Transparency = 0
			data.Health.Color = Color3.fromRGB(50, 205, 50):Lerp(Color3.fromRGB(255, 0, 0), 1 - pct)
			data.Health.Position = Vector2.new(bx, by + (bh - hh))
			data.Health.Size = Vector2.new(bw, hh)
			data.Health.Visible = true
		else
			data.Health.Visible = false
			data.HealthBg.Visible = false
		end
	end

	-- ===== NPC 扫描 =====
	-- 初始扫描（分帧）
	local function scanNPCs()
		local okd, descendants = pcall(function() return Workspace:GetDescendants() end)
		if not okd or not descendants then return end
		local count = 0
		for _, obj in ipairs(descendants) do
			if obj:IsA("Model") and isHumanoidModel(obj) then
				npcSet[obj] = true
			end
			count = count + 1
			if count % 300 == 0 then task.wait() end
		end
	end
	task.spawn(scanNPCs)

	-- DescendantAdded 增量
	conn(Workspace.DescendantAdded, function(obj)
		if obj:IsA("Model") and isHumanoidModel(obj) then
			npcSet[obj] = true
		elseif obj:IsA("Humanoid") then
			local m = obj.Parent
			if m and m:IsA("Model") and isHumanoidModel(m) then
				npcSet[m] = true
			end
		end
	end)

	conn(Workspace.DescendantRemoving, function(obj)
		if obj:IsA("Model") then
			if npcSet[obj] then
				npcSet[obj] = nil
				if espData[obj] then removeESP(obj) end
			end
		elseif obj:IsA("Humanoid") then
			local m = obj.Parent
			if m and npcSet[m] then
				npcSet[m] = nil
				if espData[m] then removeESP(m) end
			end
		end
	end)

	-- 周期性全量重扫（每 3 秒，防流式加载/延迟生成漏掉）
	task.spawn(function()
		task.wait(1.5)
		while true do
			local okd, descendants = pcall(function() return Workspace:GetDescendants() end)
			if okd and descendants then
				local i = 0
				for _, obj in ipairs(descendants) do
					if obj:IsA("Model") and isHumanoidModel(obj) then
						npcSet[obj] = true
					end
					i = i + 1
					if i % 500 == 0 then task.wait() end
				end
			end
			-- 清理失效
			for m in pairs(npcSet) do
				if not m.Parent then
					npcSet[m] = nil
					if espData[m] then removeESP(m) end
				end
			end
			task.wait(3)
		end
	end)

	-- ===== ESP 主循环 =====
	RunService.RenderStepped:Connect(function()
		Camera = Workspace.CurrentCamera
		if not Camera then return end
		local myTeam = getTeam(LP)
		local myColor = getTeamColor(LP)

		for _, player in ipairs(Players:GetPlayers()) do
			if player == LP then
				if espData[player] then removeESP(player) end
				continue
			end
			local char = player.Character
			if not char or not char.Parent then
				removeESP(player)
				continue
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso") or char.PrimaryPart
			local pTeam = getTeam(player)
			local pColor = getTeamColor(player)
			local isTeamName = myTeam and pTeam and myTeam == pTeam
			local isTeamColor = myColor and pColor and myColor == pColor
			if cfg.TeamCheck and (isTeamName or isTeamColor) then
				hideESP(player)
				cleanExtras(char)
				continue
			end
			renderESP(player, char, hum, root, player.Name, pTeam, cfg.ESP)
		end

		-- NPC 计数
		local npcCount = 0
		for _ in pairs(npcSet) do npcCount = npcCount + 1 end

		if cfg.ShowNPC then
			for model in pairs(npcSet) do
				if not model.Parent then
					npcSet[model] = nil
					if espData[model] then removeESP(model) end
					cleanExtras(model)
					continue
				end
				local hum = model:FindFirstChildOfClass("Humanoid")
				local root = findRoot(model)
				local npcName = model.Name
				if npcName == "" or npcName == "Model" or npcName == "Rig" then npcName = "NPC" end
				renderESP(model, model, hum, root, npcName, nil, true)
			end
			npcStatus.Visible = true
			npcStatus.Text = "NPC: " .. npcCount
		else
			for model in pairs(npcSet) do
				if espData[model] then removeESP(model) end
				cleanExtras(model)
			end
			npcStatus.Visible = false
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		removeESP(p)
	end)

	-- ===== 无后坐 =====
	local prevPitch = 0
	RunService:BindToRenderStep("PuppyNoRecoil", Enum.RenderPriority.Camera.Value + 100, function()
		if not cfg.NoRecoil then return end
		local char = LP.Character
		if not char then return end
		local tool = char:FindFirstChildWhichIsA("Tool")
		local pitch, yaw, roll = Camera.CFrame:ToOrientation()
		if tool then
			local d = pitch - prevPitch
			if d > 0.001 then
				local np = pitch - d
				Camera.CFrame = CFrame.new(Camera.CFrame.Position) * CFrame.Angles(np, yaw, roll)
				prevPitch = np
			else
				prevPitch = pitch
			end
		else
			prevPitch = pitch
		end
	end)
end)
