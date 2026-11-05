-- [[ // Error Handling // ]]
local Passed, Statement = pcall(function()
	-- [[ // Libraries // ]]
	local library = {
		Renders = {},
		Connections = {},
		Folder = "PuppyWare",
		Assets = "Assets",
		Configs = "Configs"
	}
	local utility = {}
	-- [[ // Tables // ]]
	local pages = {}
	local sections = {}
	-- [[ // Indexes // ]]
	do
		library.__index = library
		pages.__index = pages
		sections.__index = sections
	end
	-- [[ // Variables // ]]
	local tws = game:GetService("TweenService")
	local uis = game:GetService("UserInputService")
	local GuiParent
	do
		local ok, hui = pcall(function()
			return gethui and gethui() or nil
		end)
		if ok and hui then
			GuiParent = hui
		else
			local ok2, cg = pcall(function()
				return game:GetService("CoreGui")
			end)
			if ok2 and cg then
				GuiParent = cg
			else
				GuiParent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
			end
		end
	end
	-- [[ // Functions // ]]
	function utility:RenderObject(RenderType, RenderProperties, RenderHidden)
		local Render = Instance.new(RenderType)
		--
		if RenderProperties and typeof(RenderProperties) == "table" then
			for Property, Value in pairs(RenderProperties) do
				if Property ~= "RenderTime" then
					Render[Property] = Value
				end
			end
		end
		--
		library.Renders[#library.Renders + 1] = {Render, RenderProperties, RenderHidden, RenderProperties["RenderTime"] or nil}
		--
		return Render
	end
	--
	function utility:CreateConnection(ConnectionType, ConnectionCallback)
		local Connection = ConnectionType:Connect(ConnectionCallback)
		--
		library.Connections[#library.Connections + 1] = Connection
		--
		return Connection
	end
	--
	function utility:MouseLocation()
		return uis:GetMouseLocation()
	end
	--
	function utility:Serialise(Table)
		local Serialised = ""
		--
		for Index, Value in pairs(Table) do
			Serialised = Serialised .. Value .. ", "
		end
		--
		return Serialised:sub(0, #Serialised - 2)
	end
	--
	function utility:Sort(Table1, Table2)
		local Table3 = {}
		--
		for Index, Value in pairs(Table2) do
			if table.find(Table1, Index) then
				Table3[#Table3 + 1] = Value
			end
		end
		--
		return Table3
	end
	-- [[ // UI Functions // ]]
	function library:CreateWindow(Properties)
		Properties = Properties or {}
		--
		local Window = {
			Pages = {},
			Accent = Color3.fromRGB(255, 120, 30),
			Enabled = true,
			Key = Enum.KeyCode.Z
		}
		--
		do
			local ScreenGui = utility:RenderObject("ScreenGui", {
				DisplayOrder = 9999,
				Enabled = true,
				IgnoreGuiInset = true,
				Parent = GuiParent,
				ResetOnSpawn = false,
				ZIndexBehavior = "Global"
			})
			-- //
			local ScreenGui_MainFrame = utility:RenderObject("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(25, 25, 25),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(12, 12, 12),
				BorderMode = "Inset",
				BorderSizePixel = 1,
				Parent = ScreenGui,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = UDim2.new(0, 660, 0, 560)
			})
			-- // 手机端自适应缩放
			local MainScale = utility:RenderObject("UIScale", {
				Parent = ScreenGui_MainFrame,
				Scale = 1
			})
			local function UpdateMainScale()
				local cam = workspace.CurrentCamera
				if not cam then return end
				local vp = cam.ViewportSize
				local scale = math.min(vp.X / 720, vp.Y / 620)
				MainScale.Scale = math.clamp(scale, 0.35, 1)
			end
			UpdateMainScale()
			task.spawn(function()
				while true do
					UpdateMainScale()
					task.wait(0.5)
				end
			end)
			-- //
			local ScreenGui_MainFrame_InnerBorder = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = ScreenGui_MainFrame,
				Position = UDim2.new(0, 1, 0, 1),
				Size = UDim2.new(1, -2, 1, -2)
			})
			-- //
			local MainFrame_InnerBorder_InnerFrame = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(12, 12, 12),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(60, 60, 60),
				BorderMode = "Inset",
				BorderSizePixel = 1,
				Parent = ScreenGui_MainFrame,
				Position = UDim2.new(0, 3, 0, 3),
				Size = UDim2.new(1, -6, 1, -6)
			})
			-- //
			local InnerBorder_InnerFrame_Tabs = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(12, 12, 12),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = MainFrame_InnerBorder_InnerFrame,
				Position = UDim2.new(0, 0, 0, 4),
				Size = UDim2.new(0, 74, 1, -4)
			})
			--
			local InnerBorder_InnerFrame_Pages = utility:RenderObject("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = MainFrame_InnerBorder_InnerFrame,
				Position = UDim2.new(1, 0, 0, 4),
				Size = UDim2.new(1, -73, 1, -4)
			})
			--
			local InnerBorder_InnerFrame_TopGradient = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(12, 12, 12),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = MainFrame_InnerBorder_InnerFrame,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 0, 4)
			})
			-- //
			local InnerFrame_Tabs_List = utility:RenderObject("UIListLayout", {
				Padding = UDim.new(0, 4),
				Parent = InnerBorder_InnerFrame_Tabs,
				FillDirection = "Vertical",
				HorizontalAlignment = "Left",
				VerticalAlignment = "Top"
			})
			--
			local InnerFrame_Tabs_Padding = utility:RenderObject("UIPadding", {
				Parent = InnerBorder_InnerFrame_Tabs,
				PaddingTop = UDim.new(0, 9)
			})
			--
			local InnerFrame_Pages_InnerBorder = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(45, 45, 45),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = InnerBorder_InnerFrame_Pages,
				Position = UDim2.new(0, 1, 0, 0),
				Size = UDim2.new(1, -1, 1, 0)
			})
			--
			local InnerFrame_TopGradient_Gradient = utility:RenderObject("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = InnerBorder_InnerFrame_TopGradient,
				Position = UDim2.new(0, 1, 0, 1),
				Size = UDim2.new(1, -2, 1, -2),
				Image = "rbxassetid://8508019876",
				ImageColor3 = Color3.fromRGB(255, 255, 255)
			})
			-- //
			local Pages_InnerBorder_InnerFrame = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = InnerFrame_Pages_InnerBorder,
				Position = UDim2.new(0, 1, 0, 0),
				Size = UDim2.new(1, -1, 1, 0)
			})
			-- //
			local InnerBorder_InnerFrame_Folder = utility:RenderObject("Folder", {
				Parent = Pages_InnerBorder_InnerFrame
			})
			--
			local InnerBorder_InnerFrame_Pattern = utility:RenderObject("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Pages_InnerBorder_InnerFrame,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				Image = "rbxassetid://8547666218",
				ImageColor3 = Color3.fromRGB(12, 12, 12),
				ScaleType = "Tile",
				TileSize = UDim2.new(0, 8, 0, 8)
			})
			--
			-- // 手机端悬浮开关按钮（独立 ScreenGui，避免被菜单淡出影响）
			local ScreenGui_Toggle = utility:RenderObject("ScreenGui", {
				DisplayOrder = 10000,
				Enabled = true,
				IgnoreGuiInset = true,
				Parent = GuiParent,
				ResetOnSpawn = false,
				ZIndexBehavior = "Global"
			})
			local ToggleButton = utility:RenderObject("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(30, 30, 30),
				BackgroundTransparency = 0.15,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = ScreenGui_Toggle,
				Position = UDim2.new(1, -10, 0, 70),
				Size = UDim2.new(0, 52, 0, 52),
				Text = "P",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 20,
				Font = "Code",
				ZIndex = 10
			})
			utility:RenderObject("UICorner", {
				CornerRadius = UDim.new(0, 8),
				Parent = ToggleButton
			})
			--
			do -- // Functions
				function Window:SetPage(Page)
					for index, page in pairs(Window.Pages) do
						if page.Open and page ~= Page then
							page:Set(false)
						end
					end
				end
				--
				function Window:Fade(state)
					if state then
						ScreenGui.Enabled = true
					else
						task.delay(0.3, function()
							if not Window.Enabled then
								ScreenGui.Enabled = false
							end
						end)
					end
					--
					for index, render in pairs(library.Renders) do
						if not render[3] then
							if render[1].ClassName == "Frame" and (render[2]["BackgroundTransparency"] or 0) ~= 1 then
								tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
							elseif render[1].ClassName == "ImageLabel" then
								if (render[2]["BackgroundTransparency"] or 0) ~= 1 then
									tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
								end
								--
								if (render[2]["ImageTransparency"] or 0) ~= 1 then
									tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {ImageTransparency = state and (render[2]["ImageTransparency"] or 0) or 1}):Play()
								end
							elseif render[1].ClassName == "TextLabel" then
								if (render[2]["BackgroundTransparency"] or 0) ~= 1 then
									tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
								end
								--
								if (render[2]["TextTransparency"] or 0) ~= 1 then
									tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {TextTransparency = state and (render[2]["TextTransparency"] or 0) or 1}):Play()
								end
							elseif render[1].ClassName == "ScrollingFrame" then
								if (render[2]["BackgroundTransparency"] or 0) ~= 1 then
									tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {BackgroundTransparency = state and (render[2]["BackgroundTransparency"] or 0) or 1}):Play()
								end
								--
								if (render[2]["ScrollBarImageTransparency"] or 0) ~= 1 then
									tws:Create(render[1], TweenInfo.new(render[4] or 0.25, Enum.EasingStyle["Linear"], state and Enum.EasingDirection["Out"] or Enum.EasingDirection["In"]), {ScrollBarImageTransparency = state and (render[2]["ScrollBarImageTransparency"] or 0) or 1}):Play()
								end
							end
						end
					end
				end
				--
				function Window:Unload()
					ScreenGui:Remove()
					ScreenGui_Toggle:Remove()
					--
					for index, connection in pairs(library.Connections) do
						connection:Disconnect()
					end
					--
					library = nil
					utility = nil
				end
			end
			--
			do -- // Index Setting
				Window["TabsHolder"] = InnerBorder_InnerFrame_Tabs
				Window["PagesHolder"] = InnerBorder_InnerFrame_Folder
			end
			--
			do -- // Connections
				utility:CreateConnection(ToggleButton.MouseButton1Click, function()
					Window.Enabled = not Window.Enabled
					Window:Fade(Window.Enabled)
				end)
				--
				utility:CreateConnection(uis.InputBegan, function(Input)
					if Input.KeyCode and Input.KeyCode == Window.Key then
						Window.Enabled = not Window.Enabled
						--
						Window:Fade(Window.Enabled)
					elseif Input.KeyCode and Input.KeyCode == Enum.KeyCode.X then
						Window.Enabled = not Window.Enabled
						--
						Window:Fade(Window.Enabled)
					end
				end)
			end
		end
		--
		return setmetatable(Window, library)
	end
	--
	function library:CreatePage(Properties)
		Properties = Properties or {}
		--
		local Page = {
			Image = (Properties.image or Properties.Image or Properties.icon or Properties.Icon),
			Size = (Properties.size or Properties.Size or UDim2.new(0, 50, 0, 50)),
			Open = false,
			Window = self
		}
		--
		do
			local Page_Tab = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page.Window["TabsHolder"],
				Size = UDim2.new(1, 0, 0, 72)
			})
			-- //
			local Page_Tab_Border = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page_Tab,
				Size = UDim2.new(1, 0, 1, 0),
				Visible = false,
				ZIndex = 2,
				RenderTime = 0.15
			})
			--
			local Page_Tab_Image = utility:RenderObject("ImageLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page_Tab,
				Position = UDim2.new(0.5, 0, 0.5, 0),
				Size = Page.Size,
				ZIndex = 2,
				Image = Page.Image,
				ImageColor3 = Color3.fromRGB(100, 100, 100)
			})
			--
			local Page_Tab_Button = utility:RenderObject("TextButton", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page_Tab,
				Size = UDim2.new(1, 0, 1, 0),
				Text = ""
			})
			-- //
			local Tab_Border_Inner = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page_Tab_Border,
				Position = UDim2.new(0, 0, 0, 1),
				Size = UDim2.new(1, 1, 1, -2),
				ZIndex = 2,
				RenderTime = 0.15
			})
			-- //
			local Border_Inner_Inner = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(20, 20, 20),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Tab_Border_Inner,
				Position = UDim2.new(0, 0, 0, 1),
				Size = UDim2.new(1, 0, 1, -2),
				ZIndex = 2,
				RenderTime = 0.15
			})
			--
			local Inner_Inner_Pattern = utility:RenderObject("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Border_Inner_Inner,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				Image = "rbxassetid://8509210785",
				ImageColor3 = Color3.fromRGB(12, 12, 12),
				ScaleType = "Tile",
				TileSize = UDim2.new(0, 8, 0, 8),
				ZIndex = 2
			})
			-- //
			local Page_Page = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page.Window["PagesHolder"],
				Position = UDim2.new(0, 20, 0, 20),
				Size = UDim2.new(1, -40, 1, -40),
				Visible = false
			})
			-- //
			local Page_Page_Left = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page_Page,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(0.5, -10, 1, 0)
			})
			--
			local Page_Page_Right = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Page_Page,
				Position = UDim2.new(0.5, 10, 0, 0),
				Size = UDim2.new(0.5, -10, 1, 0)
			})
			-- //
			local Page_Left_List = utility:RenderObject("UIListLayout", {
				Padding = UDim.new(0, 18),
				Parent = Page_Page_Left,
				FillDirection = "Vertical",
				HorizontalAlignment = "Left",
				VerticalAlignment = "Top"
			})
			--
			local Page_Right_List = utility:RenderObject("UIListLayout", {
				Padding = UDim.new(0, 18),
				Parent = Page_Page_Right,
				FillDirection = "Vertical",
				HorizontalAlignment = "Left",
				VerticalAlignment = "Top"
			})
			--
			do -- // Index Setting
				Page["Page"] = Page_Page
				Page["Left"] = Page_Page_Left
				Page["Right"] = Page_Page_Right
			end
			--
			do -- // Functions
				function Page:Set(state)
					Page.Open = state
					--
					Page_Page.Visible = Page.Open
					Page_Tab_Border.Visible = Page.Open
					Page_Tab_Image.ImageColor3 = Page.Open and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 90)
					--
					if Page.Open then
						Page.Window:SetPage(Page)
					end
				end
			end
			--
			do -- // Connections
				utility:CreateConnection(Page_Tab_Button.MouseButton1Click, function(Input)
					if not Page.Open then
						Page:Set(true)
					end
				end)
				--
				utility:CreateConnection(Page_Tab_Button.MouseEnter, function(Input)
					Page_Tab_Image.ImageColor3 = Color3.fromRGB(172, 172, 172)
				end)
				--
				utility:CreateConnection(Page_Tab_Button.MouseLeave, function(Input)
					Page_Tab_Image.ImageColor3 = Page.Open and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(90, 90, 90)
				end)
			end
		end
		--
		if #Page.Window.Pages == 0 then Page:Set(true) end
		Page.Window.Pages[#Page.Window.Pages + 1] = Page
		return setmetatable(Page, pages)
	end
	--
	function pages:CreateSection(Properties)
		Properties = Properties or {}
		--
		local Section = {
			Name = (Properties.name or Properties.Name or Properties.title or Properties.Title or "New Section"),
			Size = (Properties.size or Properties.Size or 150),
			Side = (Properties.side or Properties.Side or "Left"),
			Content = {},
			Window = self.Window,
			Page = self
		}
		--
		do
			local Section_Holder = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(12, 12, 12),
				BorderMode = "Inset",
				BorderSizePixel = 1,
				Parent = Section.Page[Section.Side],
				Size = UDim2.new(1, 0, 0, Section.Size),
				ZIndex = 2
			})
			-- //
			local Section_Holder_Extra = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder,
				Position = UDim2.new(0, 1, 0, 1),
				Size = UDim2.new(1, -2, 1, -2),
				ZIndex = 2
			})
			--
			local Section_Holder_Frame = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(23, 23, 23),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder,
				Position = UDim2.new(0, 1, 0, 1),
				Size = UDim2.new(1, -2, 1, -2),
				ZIndex = 2
			})
			--
			local Section_Holder_TitleInline = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(23, 23, 23),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder,
				Position = UDim2.new(0, 9, 0, -1),
				Size = UDim2.new(0, 0, 0, 2),
				ZIndex = 5
			})
			--
			local Section_Holder_Title = utility:RenderObject("TextLabel", {
				AnchorPoint = Vector2.new(0, 0.5),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder,
				Position = UDim2.new(0, 12, 0, 0),
				Size = UDim2.new(1, -26, 0, 15),
				ZIndex = 5,
				Font = "Code",
				RichText = true,
				Text = "<b>" .. Section.Name .. "</b>",
				TextColor3 = Color3.fromRGB(205, 205, 205),
				TextSize = 11,
				TextStrokeTransparency = 1,
				TextXAlignment = "Left"
			})
			-- //
			local Holder_Extra_Gradient1 = utility:RenderObject("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder_Extra,
				Position = UDim2.new(0, 1, 0, 1),
				Rotation = 180,
				Size = UDim2.new(1, -2, 0, 20),
				Visible = false,
				ZIndex = 4,
				Image = "rbxassetid://7783533907",
				ImageColor3 = Color3.fromRGB(23, 23, 23)
			})
			--
			local Holder_Extra_Gradient2 = utility:RenderObject("ImageLabel", {
				AnchorPoint = Vector2.new(0, 1),
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder_Extra,
				Position = UDim2.new(0, 0, 1, 0),
				Size = UDim2.new(1, -2, 0, 20),
				Visible = false,
				ZIndex = 4,
				Image = "rbxassetid://7783533907",
				ImageColor3 = Color3.fromRGB(23, 23, 23)
			})
			--
			local Holder_Extra_ArrowUp = utility:RenderObject("TextButton", {
				BackgroundColor3 = Color3.fromRGB(255, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder_Extra,
				Position = UDim2.new(1, -21, 0, 0),
				Size = UDim2.new(0, 7 + 8, 0, 6 + 8),
				Text = "",
				Visible = false,
				ZIndex = 4
			})
			--
			local Holder_Extra_ArrowDown = utility:RenderObject("TextButton", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder_Extra,
				Position = UDim2.new(1, -21, 1, -(6 + 8)),
				Size = UDim2.new(0, 7 + 8, 0, 6 + 8),
				Text = "",
				Visible = false,
				ZIndex = 4
			})
			-- //
			local Extra_ArrowUp_Image = utility:RenderObject("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Holder_Extra_ArrowUp,
				Position = UDim2.new(0, 4, 0, 4),
				Size = UDim2.new(0, 7, 0, 6),
				Visible = true,
				ZIndex = 4,
				Image = "rbxassetid://8548757311",
				ImageColor3 = Color3.fromRGB(205, 205, 205)
			})
			--
			local Extra_ArrowDown_Image = utility:RenderObject("ImageLabel", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Holder_Extra_ArrowDown,
				Position = UDim2.new(0, 4, 0, 4),
				Size = UDim2.new(0, 7, 0, 6),
				Visible = true,
				ZIndex = 4,
				Image = "rbxassetid://8548723563",
				ImageColor3 = Color3.fromRGB(205, 205, 205)
			})
			--
			local Holder_Extra_Bar = utility:RenderObject("Frame", {
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(45, 45, 45),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder_Extra,
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.new(0, 6, 1, 0),
				Visible = false,
				ZIndex = 4
			})
			--
			local Holder_Extra_Line = utility:RenderObject("Frame", {
				BackgroundColor3 = Color3.fromRGB(45, 45, 45),
				BackgroundTransparency = 0,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder_Extra,
				Position = UDim2.new(0, 0, 0, -1),
				Size = UDim2.new(1, 0, 0, 1),
				ZIndex = 4
			})
			--
			local Holder_Frame_ContentHolder = utility:RenderObject("ScrollingFrame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Parent = Section_Holder_Frame,
				Position = UDim2.new(0, 0, 0, 0),
				Size = UDim2.new(1, 0, 1, 0),
				ZIndex = 4,
				AutomaticCanvasSize = "Y",
				BottomImage = "rbxassetid://7783554086",
				CanvasSize = UDim2.new(0, 0, 0, 0),
				MidImage = "rbxassetid://7783554086",
				ScrollBarImageColor3 = Color3.fromRGB(65, 65, 65),
				ScrollBarImageTransparency = 0,
				ScrollBarThickness = 5,
				TopImage = "rbxassetid://7783554086",
				VerticalScrollBarInset = "None"
			})
			-- //
			local Frame_ContentHolder_List = utility:RenderObject("UIListLayout", {
				Padding = UDim.new(0, 0),
				Parent = Holder_Frame_ContentHolder,
				FillDirection = "Vertical",
				HorizontalAlignment = "Center",
				VerticalAlignment = "Top"
			})
			--
			local Frame_ContentHolder_Padding = utility:RenderObject("UIPadding", {
				Parent = Holder_Frame_ContentHolder,
				PaddingTop = UDim.new(0, 15),
				PaddingBottom = UDim.new(0, 15)
			})
			--
			do -- // Section Init
				Section_Holder_TitleInline.Size = UDim2.new(0, Section_Holder_Title.TextBounds.X + 6, 0, 2)
			end
			--
			do -- // Index Setting
				Section["Holder"] = Holder_Frame_ContentHolder
				Section["Extra"] = Section_Holder_Extra
			end
			--
			do -- // Functions
				function Section:CloseContent()
					if Section.Content.Open then
						Section.Content:Close()
						--
						Section.Content = {}
					end
				end
			end
			--
			do -- // Connections
				utility:CreateConnection(Holder_Frame_ContentHolder:GetPropertyChangedSignal("AbsoluteCanvasSize"), function()
					Holder_Extra_Gradient1.Visible = Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y > Holder_Frame_ContentHolder.AbsoluteWindowSize.Y
					Holder_Extra_Gradient2.Visible = Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y > Holder_Frame_ContentHolder.AbsoluteWindowSize.Y
					Holder_Extra_Bar.Visible = Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y > Holder_Frame_ContentHolder.AbsoluteWindowSize.Y
					--
					if (Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y > Holder_Frame_ContentHolder.AbsoluteWindowSize.Y) then
						Holder_Extra_ArrowUp.Visible = (Holder_Frame_ContentHolder.CanvasPosition.Y > 5)
						Holder_Extra_ArrowDown.Visible = (Holder_Frame_ContentHolder.CanvasPosition.Y + 5 < (Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y - Holder_Frame_ContentHolder.AbsoluteSize.Y))
					end
				end)
				--
				utility:CreateConnection(Holder_Frame_ContentHolder:GetPropertyChangedSignal("CanvasPosition"), function()
					if Section.Content.Open then
						Section.Content:Close()
						--
						Section.Content = {}
					end
					--
					Holder_Extra_ArrowUp.Visible = (Holder_Frame_ContentHolder.CanvasPosition.Y > 1)
					Holder_Extra_ArrowDown.Visible = (Holder_Frame_ContentHolder.CanvasPosition.Y + 1 < (Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y - Holder_Frame_ContentHolder.AbsoluteSize.Y))
				end)
				--
				utility:CreateConnection(Holder_Extra_ArrowUp.MouseButton1Click, function()
					Holder_Frame_ContentHolder.CanvasPosition = Vector2.new(0, math.clamp(Holder_Frame_ContentHolder.CanvasPosition.Y - 10, 0, Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y - Holder_Frame_ContentHolder.AbsoluteSize.Y))
				end)
				--
				utility:CreateConnection(Holder_Extra_ArrowDown.MouseButton1Click, function()
					Holder_Frame_ContentHolder.CanvasPosition = Vector2.new(0, math.clamp(Holder_Frame_ContentHolder.CanvasPosition.Y + 10, 0, Holder_Frame_ContentHolder.AbsoluteCanvasSize.Y - Holder_Frame_ContentHolder.AbsoluteSize.Y))
				end)
			end
		end
		--
		return setmetatable(Section, sections)
	end
	--
	do -- // Content
		function sections:CreateToggle(Properties)
			Properties = Properties or {}
			--
			local Content = {
				Name = (Properties.name or Properties.Name or Properties.title or Properties.Title or "New Toggle"),
				State = (Properties.state or Properties.State or Properties.def or Properties.Def or Properties.default or Properties.Default or false),
				Callback = (Properties.callback or Properties.Callback or Properties.callBack or Properties.CallBack or function() end),
				Window = self.Window,
				Page = self.Page,
				Section = self
			}
			--
			do
				local Content_Holder = utility:RenderObject("Frame", {
					BackgroundColor3 = Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Parent = Content.Section.Holder,
					Size = UDim2.new(1, 0, 0, 8 + 10),
					ZIndex = 3
				})
				-- //
				local Content_Holder_Outline = utility:RenderObject("Frame", {
					BackgroundColor3 = Color3.fromRGB(12, 12, 12),
					BackgroundTransparency = 0,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Parent = Content_Holder,
					Position = UDim2.new(0, 20, 0, 5),
					Size = UDim2.new(0, 8, 0, 8),
					ZIndex = 3
				})
				--
				local Content_Holder_Title = utility:RenderObject("TextLabel", {
					AnchorPoint = Vector2.new(0, 0),
					BackgroundColor3 = Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Parent = Content_Holder,
					Position = UDim2.new(0, 41, 0, 0),
					Size = UDim2.new(1, -41, 1, 0),
					ZIndex = 3,
					Font = "Code",
					RichText = true,
					Text = Content.Name,
					TextColor3 = Color3.fromRGB(205, 205, 205),
					TextSize = 9,
					TextStrokeTransparency = 1,
					TextXAlignment = "Left"
				})
				--
				local Content_Holder_Title2 = utility:RenderObject("TextLabel", {
					AnchorPoint = Vector2.new(0, 0),
					BackgroundColor3 = Color3.fromRGB(0, 0, 0),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Parent = Content_Holder,
					Position = UDim2.new(0, 41, 0, 0),
					Size = UDim2.new(1, -41, 1, 0),
					ZIndex = 3,
					Font = "C
