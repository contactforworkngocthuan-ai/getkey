--[[
  MOBILE KEY GATE
  Replace KEY_SERVER with your deployed HTTPS app URL.
  Server secrets stay on the server; never paste them into this file.
]]
local KEY_SERVER = "https://YOUR-PROJECT.vercel.app"

local function runKeyGate()
    local keyPlayers = game:GetService("Players")
    local keyHttp = game:GetService("HttpService")
    local keyUserInputService = game:GetService("UserInputService")
    local keyPlayer = keyPlayers.LocalPlayer
    if not keyPlayer then
        keyPlayer = keyPlayers.PlayerAdded:Wait()
    end

    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request
    if type(httpRequest) ~= "function" then
        warn("[KeyGate] This executor does not expose an HTTP request function.")
        return false
    end

    local function apiPost(route, payload)
        local ok, response = pcall(httpRequest, {
            Url = KEY_SERVER .. route,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = keyHttp:JSONEncode(payload)
        })
        if not ok or type(response) ~= "table" then
            return nil, "Network request failed. Check your connection and server URL."
        end
        local rawBody = response.Body or response.body or ""
        local decodeOk, data = pcall(function()
            return keyHttp:JSONDecode(rawBody)
        end)
        if not decodeOk or type(data) ~= "table" then
            return nil, "The key server returned an invalid response."
        end
        local statusCode = tonumber(response.StatusCode or response.Status or 200) or 200
        if statusCode < 200 or statusCode >= 300 or data.ok ~= true then
            return nil, data.error or ("Server error: " .. tostring(statusCode))
        end
        return data
    end

    local uiParent
    if type(gethui) == "function" then
        local ok, result = pcall(gethui)
        if ok and result then uiParent = result end
    end
    if not uiParent then
        uiParent = keyPlayer:WaitForChild("PlayerGui")
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "KxyAngelKeyGate"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.DisplayOrder = 999999
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = uiParent

    local frame = Instance.new("Frame")
    frame.Name = "AngelPanel"
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.Position = UDim2.fromScale(0.5, 0.5)
    frame.Size = UDim2.new(0.88, 0, 0, 290)
    frame.SizeConstraint = Enum.SizeConstraint.RelativeXY
    local sizeLimit = Instance.new("UISizeConstraint")
    sizeLimit.MinSize = Vector2.new(280, 280)
    sizeLimit.MaxSize = Vector2.new(430, 290)
    sizeLimit.Parent = frame
    frame.BackgroundColor3 = Color3.fromRGB(37, 29, 66)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = true
    frame.Parent = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 20)

    local panelGradient = Instance.new("UIGradient")
    panelGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(42, 34, 76)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(64, 54, 105)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(43, 53, 91))
    })
    panelGradient.Rotation = 28
    panelGradient.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(211, 199, 255)
    stroke.Transparency = 0.22
    stroke.Thickness = 1.5
    stroke.Parent = frame

    -- Soft angelic header glow.
    local header = Instance.new("Frame")
    header.Name = "AngelHeader"
    header.Size = UDim2.new(1, 0, 0, 69)
    header.BackgroundColor3 = Color3.fromRGB(170, 153, 225)
    header.BackgroundTransparency = 0.10
    header.BorderSizePixel = 0
    header.ZIndex = 1
    header.Parent = frame
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 20)
    local headerGradient = Instance.new("UIGradient")
    headerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(176, 157, 235)),
        ColorSequenceKeypoint.new(0.55, Color3.fromRGB(154, 178, 239)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(222, 179, 232))
    })
    headerGradient.Rotation = 12
    headerGradient.Parent = header

    local function makeLabel(name, text, position, size, color, textSize)
        local label = Instance.new("TextLabel")
        label.Name = name
        label.Position = position
        label.Size = size
        label.BackgroundTransparency = 1
        label.Text = text
        label.TextColor3 = color or Color3.fromRGB(246, 241, 255)
        label.TextSize = textSize or 15
        label.Font = Enum.Font.Gotham
        label.TextWrapped = true
        label.ZIndex = 3
        label.Parent = frame
        return label
    end

    local function makeButton(name, text, position, color)
        local button = Instance.new("TextButton")
        button.Name = name
        button.Position = position
        button.Size = UDim2.new(1, -32, 0, 42)
        button.BackgroundColor3 = color
        button.BorderSizePixel = 0
        button.Text = text
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.TextSize = 14
        button.Font = Enum.Font.GothamBold
        button.AutoButtonColor = true
        button.ZIndex = 4
        button.Parent = frame
        Instance.new("UICorner", button).CornerRadius = UDim.new(0, 12)
        local gradient = Instance.new("UIGradient")
        gradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, color),
            ColorSequenceKeypoint.new(1, color:Lerp(Color3.fromRGB(231, 219, 255), 0.42))
        })
        gradient.Rotation = 0
        gradient.Parent = button
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(239, 229, 255)
        outline.Transparency = 0.58
        outline.Thickness = 1
        outline.Parent = button
        return button
    end

    local function makeBox(name, placeholder, position)
        local box = Instance.new("TextBox")
        box.Name = name
        box.Position = position
        box.Size = UDim2.new(1, -32, 0, 42)
        box.BackgroundColor3 = Color3.fromRGB(34, 30, 61)
        box.BackgroundTransparency = 0.08
        box.BorderSizePixel = 0
        box.PlaceholderText = placeholder
        box.PlaceholderColor3 = Color3.fromRGB(185, 177, 215)
        box.Text = ""
        box.TextColor3 = Color3.fromRGB(250, 247, 255)
        box.TextSize = 13
        box.Font = Enum.Font.Gotham
        box.ClearTextOnFocus = false
        box.TextXAlignment = Enum.TextXAlignment.Left
        box.TextWrapped = false
        box.ZIndex = 4
        box.Parent = frame
        Instance.new("UICorner", box).CornerRadius = UDim.new(0, 12)
        local outline = Instance.new("UIStroke")
        outline.Color = Color3.fromRGB(194, 181, 245)
        outline.Transparency = 0.62
        outline.Thickness = 1
        outline.Parent = box
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, 12)
        padding.PaddingRight = UDim.new(0, 12)
        padding.Parent = box
        return box
    end

    -- Tiny stars give the panel a celestial background without external assets.
    local starSpecs = {
        {"✦", 0.05, 0.30, 15}, {"✧", 0.88, 0.34, 18},
        {"⋆", 0.91, 0.72, 17}, {"✧", 0.07, 0.78, 13},
        {"·", 0.48, 0.72, 18}, {"✦", 0.79, 0.90, 11}
    }
    for index, spec in ipairs(starSpecs) do
        local star = Instance.new("TextLabel")
        star.Name = "AngelStar" .. tostring(index)
        star.BackgroundTransparency = 1
        star.Text = spec[1]
        star.TextColor3 = Color3.fromRGB(226, 218, 255)
        star.TextTransparency = 0.48
        star.TextSize = spec[4]
        star.Font = Enum.Font.GothamBold
        star.Size = UDim2.fromOffset(22, 22)
        star.Position = UDim2.new(spec[2], 0, spec[3], 0)
        star.ZIndex = 2
        star.Parent = frame
    end

    local titleLabel = makeLabel("Title", "Kxy🪽", UDim2.new(0, 18, 0, 8), UDim2.new(1, -36, 0, 31), Color3.fromRGB(255, 255, 255), 23)
    titleLabel.Font = Enum.Font.GothamBlack
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Active = true
    local infoLabel = makeLabel("Info", "ANGEL KEY SYSTEM   •   DRAG TO MOVE", UDim2.new(0, 16, 0, 39), UDim2.new(1, -32, 0, 18), Color3.fromRGB(246, 240, 255), 9)
    infoLabel.Font = Enum.Font.GothamBold
    infoLabel.TextTransparency = 0.12

    -- Drag the panel from the title area (mouse or touchscreen).
    local dragInput, dragStart, startPosition
    titleLabel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
            dragStart = input.Position
            startPosition = frame.Position
        end
    end)
    titleLabel.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    keyUserInputService.InputChanged:Connect(function(input)
        if dragInput and input == dragInput and dragStart and startPosition then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPosition.X.Scale, startPosition.X.Offset + delta.X,
                startPosition.Y.Scale, startPosition.Y.Offset + delta.Y)
        end
    end)
    keyUserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragInput, dragStart, startPosition = nil, nil, nil
        end
    end)

    local getButton = makeButton("GetKey", "✧  GET KEY  •  COPY LINK  ✧", UDim2.new(0, 16, 0, 78), Color3.fromRGB(130, 112, 205))
    local keyBox = makeBox("KeyBox", "Paste your key here", UDim2.new(0, 16, 0, 128))
    local verifyButton = makeButton("Verify", "VERIFY KEY", UDim2.new(0, 16, 0, 178), Color3.fromRGB(105, 132, 204))
    local statusLabel = makeLabel("Status", "Waiting for key…", UDim2.new(0, 18, 0, 229), UDim2.new(1, -36, 0, 44), Color3.fromRGB(242, 224, 255), 11)
    statusLabel.BackgroundColor3 = Color3.fromRGB(30, 27, 54)
    statusLabel.BackgroundTransparency = 0.28
    statusLabel.TextXAlignment = Enum.TextXAlignment.Center
    statusLabel.TextYAlignment = Enum.TextYAlignment.Center
    Instance.new("UICorner", statusLabel).CornerRadius = UDim.new(0, 10)

    local authorized = false
    local busy = false

    getButton.Activated:Connect(function()
        if busy then return end
        busy = true
        getButton.Text = "CREATING LINK…"
        statusLabel.Text = "Connecting securely to the key server…"
        task.spawn(function()
            local data, err = apiPost("/api/start", { userId = tostring(keyPlayer.UserId) })
            if data and data.shortUrl then
                local clipboard = setclipboard or toclipboard
                local copied = false
                if type(clipboard) == "function" then
                    copied = pcall(function() clipboard(data.shortUrl) end)
                end
                local browserOpened = pcall(function()
                    game:GetService("GuiService"):OpenBrowserWindow(data.shortUrl)
                end)
                if copied then
                    statusLabel.Text = "✨ Đã sao chép link thành công! Mở trình duyệt để hoàn tất."
                elseif browserOpened then
                    statusLabel.Text = "Link đã được mở. Executor này không hỗ trợ tự sao chép clipboard."
                else
                    statusLabel.Text = "Không thể sao chép/mở link. Link: " .. tostring(data.shortUrl)
                end
            else
                statusLabel.Text = err or "Could not create your key link."
            end
            getButton.Text = "✧  GET KEY  •  COPY LINK  ✧"
            busy = false
        end)
    end)

    verifyButton.Activated:Connect(function()
        if busy then return end
        local suppliedKey = string.gsub(keyBox.Text or "", "^%s*(.-)%s*$", "%1")
        if suppliedKey == "" then
            statusLabel.Text = "Paste your key first."
            return
        end
        busy = true
        verifyButton.Text = "VERIFYING…"
        statusLabel.Text = "Checking key and Roblox account…"
        task.spawn(function()
            local data, err = apiPost("/api/validate", {
                key = suppliedKey,
                userId = tostring(keyPlayer.UserId)
            })
            if data and data.ok then
                authorized = true
                statusLabel.Text = "Key accepted. Loading script…"
                screenGui:Destroy()
            else
                statusLabel.Text = err or "Key rejected. Check it and try again."
            end
            verifyButton.Text = "VERIFY KEY"
            busy = false
        end)
    end)

    while not authorized do
        if not screenGui.Parent then return false end
        task.wait(0.15)
    end
    return true
end

if not runKeyGate() then
    return
end

-- Hood Aimbot + ESP Mobile v12.0 — AIM DRIFT FIX + ALLY/CREW/CLAN SKIP
-- PlaceId: 84448037861644 | R15 rig | Camera type: Scriptable
-- wallCheck chuẩn | FOV strict | Aim 550m | ESP 650m
-- Foliage bypass + Anti-Aim AD Strafe + Flick Legit + FPS Boost cho máy yếu
--
-- ═══════ v12.0 CHANGES ═══════
-- ✓ ALLY / CREW / CLAN SKIP — 3 lớp bảo vệ, không aim vào đồng đội:
--   [Lớp 1] CREW — CollisionGroup "CrewChar" trên HRP:
--     → Game server set khi join crew → không thể spoof từ client
--     → Check isCrewMate(char) = hrp.CollisionGroup == "CrewChar"
--   [Lớp 2] CLAN — ClanQuery RemoteFunction:
--     → Query clanId của lp lúc load, cache clanId của từng player (TTL 30s)
--     → Fetch async trong task.spawn → không block aim loop
--     → Dùng cached value cũ trong khi đang fetch lại
--   [Lớp 3] MANUAL ALLY — allySet table:
--     → Toggle thủ công qua allySet[player] = true/nil
--     → Có thể gắn GUI sau, hoặc dùng trực tiếp từ script khác
--   → isAllyPlayer() check cả 3 lớp trong isTargetValid() và pickTarget()
--   → Lock drop tức thì nếu target trở thành ally mid-lock
--   → clanCache cleanup khi player rời game
-- ✓ XÓA FPS BOOST (theo yêu cầu)
--
-- ═══════ v11.0 CHANGES ═══════
-- ✓ AIM DRIFT FIX (aim lệch khi xa / xoay người) — 3 bug cộng dồn:
--
--   [Fix 1] w2s() — tách rawPos vs drawPos:
--     → rawPos: tọa độ pixel trước stretchX (dùng cho FOV check / pickTarget)
--     → drawPos: tọa độ pixel sau stretchX (dùng để vẽ ESP box)
--     → Bug cũ: pickTarget dùng fixedX (đã stretch 0.75×) để tính screenDist
--       → target sang bên: X compress lại → screenDist nhỏ hơn thực → FOV check pass sai chỗ
--       → tâm súng (3D correct) và địch (pixel distorted) nhìn thấy ở 2 chỗ khác nhau
--
--   [Fix 2] smoothLookAt() — noise theo camera-local axes:
--     → Bug cũ: humanize noise = Vector3.new(nx, ny, 0) = world XY cứng
--       → khi camera nhìn chéo / sang bên, trục Y world ≠ trục Y screen
--       → noise push aim theo hướng sai, lệch nhiều khi xa (góc lớn hơn)
--     → Fix: noise project lên camCF.RightVector và camCF.UpVector (screen-space aligned)
--
--   [Fix 3] getAimPos() fallback HRP + neckOffset — local space:
--     → Bug cũ: hrp.Position + Vector3(x, y, z) = cộng thẳng world-space
--       → khi địch xoay người, offset Z (-0.028) bị lệch ra ngoài thân
--     → Fix: hrp.CFrame:PointToWorldSpace(localOffset) → đúng dù địch quay hướng nào
--
-- ✓ FPS BOOST v11.0 (enhanced):
--     → SurfaceAppearance: Destroy() hoàn toàn thay vì set Roughness/Metalness
--       (cách cũ không giảm texture fetch, Destroy() mới thực sự giảm PBR load)
--     → Xóa SelectionBox, BillboardGui, SurfaceGui decorative trong Map
--     → Sound.MaxDistance cap 100 studs (giảm audio mix overhead)
--
-- ═══════ v10.0 CHANGES ═══════
-- ✓ FPS BOOST (máy yếu) — không xóa tracer, không xóa kill FX:
--     → Lighting: GlobalShadows OFF, Technology Compatibility, FogEnd 2000→9999 (tắt fog draw)
--     → workspace.StreamingEnabled đã ON (xác nhận từ dump) — giữ nguyên
--     → workspace.Terrain.WaterWaveSize/WaterWaveSpeed = 0 (giảm water sim)
--     → Tất cả MeshPart/SpecialMesh trong Map không phải char: RenderFidelity Automatic→Performance
--       (batch qua descendants, skip nếu có SafeBody/Ragdoll/Hitbox → không touch char/veh hitbox)
--     → Particle throttle: MaxParticles mỗi ParticleEmitter trong Workspace (không phải PlayerGui/char)
--       giảm 50% — giảm smoke/fire ambient, KHÔNG touch emitter nằm trong character (kill FX an toàn)
--     → SunRays/Bloom/ColorCorrection/DepthOfField: Enabled = false
--     → RunService loop tối ưu: ESP loop chỉ chạy khi espOn=true (đã có, giữ)
--     → FPS cap suggestion: settings.RenderSettings mới bỏ trên Roblox mobile — không set
--
-- ═══════ v9.9.4 CHANGES ═══════
-- ✓ AIMBOT SPEED UP — trackSpeed 0.32 → 0.45 (aim nhanh hơn, không còn cảm giác lag sau)
-- ✓ CLOSE-RANGE OVERSHOOT FIX — aim tâm đi trước khi bắn địch gần không còn bắn hụt:
--     → velPredScale: 0.085 → 0.065s (ít lead hơn ở mọi khoảng cách)
--     → velPredFadeIn: 12 → 15 studs/s (prediction không kick in khi địch strafing gần)
--     → distBoostMax: 25 → 18 studs (khu vực close-range hẹp hơn)
--     → distMaxBoost: 0.12 → 0.06 (bonus track speed tại point-blank giảm một nửa)
--     → Angular vel compensation vẫn còn, chỉ nhẹ hơn để không overshoot
--
-- ═══════ v9.9.3 CHANGES ═══════
-- ✓ TRACKER FIX — aim bám kịp địch di chuyển nhanh / gần:
--     → computeAimSpeed: linear boost → quadratic (gentle start, aggressive at speed)
--     → adaptMaxBoost: 0.36→0.50 | adaptVelRef: 22→16 studs/s (kick in sớm hơn)
--     → distBoostMax=25studs + distMaxBoost=0.12: angular vel compensation close-range
--     → One-sided EMA: attack=0.45 (vel tăng → catch up nhanh), decay=0.18 (vel giảm)
--     → Dynamic velPredScale: 1×→1.4× theo velocity (more lead for fast movers)
--
-- ═══════ v9.9.2 CHANGES ═══════
-- ✓ FIX NECK AIM DRIFT — aim neck không còn miss khi địch strafing / AD spam:
--     → velPredFadeIn: 8 → 12 studs/s (chỉ lead khi địch chạy thẳng thực sự)
--     → velSmooth = 0.18: EMA velocity filter, predPos không nhảy khi AD spam
--     → noise scale 0.012 → 0.006: giảm Perlin drift trong burst
--     → smoothedVel reset khi đổi target
--
-- ═══════ v9.9.1 CHANGES ═══════
-- ✓ FIX TAP-FIRE LOCK PERSIST — shotgun / mk14 / semi-auto không còn giật:
--     → tapGapWindow = 0.18s: giữ lock giữa các tap liên tục
--       → trước: fireEnded → drop lock → fireStarted → pick lại → flick lại
--       → giờ: nhả cò → set expire timer, tap lại trong 0.18s = cùng lock, không flick
--     → lock thực sự expire khi: dừng tap > 0.18s, hoặc target invalid (dead/LOS/range)
--     → auto-fire (hold) không ảnh hưởng — logic giữ nguyên
--
-- ═══════ v9.9 CHANGES ═══════
-- ✓ FIX VEHICLE PERSON TRACKER — aim người trên xe không còn hụt:
--     → headTopBias: 0.25 → 0.0 (aim TÂMM head thay vì đỉnh skull)
--       → đỉnh skull bị overshoot khi xe xóc/nhảy — tâm head = hitbox stable nhất
--     → vehPredScale: 0.11 → 0.065 (giảm lead prediction)
--       → 0.11s × 50stud/s = 5.5 studs lead quá lớn khi xe quẹo gấp
--       → 0.065s × 50stud/s = 3.25 studs — đủ lead mà không miss khi quẹo
--     → vehTrackSpeed: giữ nguyên 0.88 (tracker đã dính tốt)
--
-- ═══════ v9.8 (giữ) ═══════
-- ✓ VEHICLE HEAD TRACKER — siêu dính:
--     → aimpart: Head.Position trực tiếp (live bone, không dùng HRP + static offset)
--       → chính xác hơn khi ngồi/xe quẹo/xe tăng tốc — head luôn đúng chỗ
--     → velocity prediction BẬT cho vehicle: vehPredScale=0.11s lead
--       → không fade-in (xe luôn di chuyển, không cần noise guard)
--       → VehicleRoot.AssemblyLinearVelocity ưu tiên hơn HRP (ít jitter hơn)
--     → vehTrackSpeed=0.88: smooth sticky tracker thay cho snap 1.0
--       → 0.88 đủ dán chặt mà không nhảy giật khung → cảm giác aim dính như keo
--     → vehPredMin=1.5 studs/s: predict ngay khi xe bắt đầu lăn
--
-- ═══════ v9.7 (giữ) ═══════
-- ✓ VELOCITY PREDICTION: HRP.AssemblyLinearVelocity × velPredScale
--     → lead aim point trước chỗ địch chạy đến (cả ngang lẫn dọc/nhảy)
--     → fade-in khi vel < velPredFadeIn (8 studs/s) → không noise khi đứng yên
-- ✓ ADAPTIVE TRACKSPEED: boost tỉ lệ theo vận tốc ngang địch
--     → đứng yên: trackSpeed gốc (0.32)
--     → sprint full (~22 studs/s): +0.36 → 0.68 total (bám chặt, không snap)
--     → stack ON TOP of flick system, không replace
--
-- ═══════ v9.6 (giữ) ═══════
-- ✓ AIMPART NECK (chính xác): thay head aim bằng NeckRigAttachment.WorldPosition
--     → UpperTorso.NeckRigAttachment (joint R15 chính xác từ dump game)
--     → Fallback: HRP + Vector3(0.020, 0.673, -0.028) (computed từ bone dump)
--
-- ═══════ v9.5 (giữ) ═══════
-- ✓ FLICK LEGIT: target trong FOV nhưng xa crosshair (>flickThreshold px)
--   → flick nhanh 0.58 → giảm về 0.32 trong 250ms (ease-out)
--   → cảm giác như người chơi vuốt chuột, KHÔNG snap cứng
-- ✓ ADAPTIVE SPEED: gần tâm → track chậm, xa tâm → flick
-- ✓ Giữ nguyên: head offset dump, velocity prediction, foliage bypass
--
-- ═══════ v9.4 (giữ) ═══════
-- ✓ HEAD OFFSET: HRP + Vector3(0.020, 1.107, -0.040) (reference, v9.8 dùng live head)
-- ✓ AC-SAFE AIM: micro-random offset nhỏ
-- ✓ TARGET PRIORITY: gần tâm FOV nhất
-- ✓ XÓA movement jitter / AutoCrouch / AutoJump

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local lp     = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- ═══════════════════════════════════════════════════════════
--  CONFIG
-- ═══════════════════════════════════════════════════════════
local CFG = {
    fov           = 150,
    aimDist       = 550,
    espDist       = 650,
    aimOn         = true,
    espOn         = true,
    wallCheck     = true,
    foliageBypass = true,
    stretchX      = 0.75,

    -- TRACK SPEED (bám mượt khi target gần crosshair)
    trackSpeed    = 0.45,  -- [v9.9.4] 0.32 → 0.45: aim nhanh hơn, không còn lag sau target

    -- FLICK (target trong FOV nhưng xa crosshair → flick nhanh legit)
    flickThreshold = 55,     -- px: screen-dist > ngưỡng này → kích hoạt flick
    flickSpeed     = 0.58,   -- tốc độ flick đỉnh (nhanh nhưng không snap cứng)
    flickEaseTime  = 0.25,   -- giây: ease-out từ flickSpeed → trackSpeed

    -- Compat (không dùng nữa, currentAimSpeed() thay thế)
    smoothSpeed   = 0.45,  -- [v9.9.4] mirror trackSpeed

    -- HEAD OFFSET từ HRP (dump từ game thực) — dùng cho VEHICLE mode
    -- R15 rig: Head Δpos=(0.020, 1.107, -0.040) relative to HRP
    headOffsetY   = 1.107,

    -- NECK OFFSET từ HRP (derived from bone dump - R15)
    -- Head bottom  : headOffsetY(1.107) - headSize(1.126)/2 = 0.544
    -- UpperTorso top: upperTorsoOffsetY(-0.160) + upperTorsoSize(1.662)/2 = 0.671
    -- → top of UpperTorso = neck joint Y ≈ 0.673
    -- Dùng khi NeckRigAttachment không tìm thấy (fallback)
    neckOffsetY   = 0.673,
    neckOffsetX   = 0.020,  -- same X axis as head
    neckOffsetZ   = -0.028, -- UpperTorso Z (-0.028) vì neck gắn ở đó

    -- VELOCITY PREDICTION (lead aim trước chỗ địch chạy đến)
    -- predPos = smoothVel * velPredScale  (smoothVel = EMA của HRP vel, tránh predPos nhảy khi AD spam)
    velPredScale  = 0.065,  -- [v9.9.4] 0.085 → 0.065s: giảm lead, giảm overshoot gần
    velPredFadeIn = 15,     -- [v9.9.4] 12 → 15 studs/s: prediction chỉ kick in khi địch chạy thẳng nhanh
                            -- → gần + strafing (<15stud/s) = không lead → không overshoot tâm
    velSmooth     = 0.18,   -- EMA alpha cho smoothed velocity: 0.18 = lag ~3 frame @ 60fps
                            -- đủ để tắt bớt jerk khi AD đổi hướng, không làm mất lead khi chạy thẳng

    -- TAP-FIRE LOCK PERSIST (shotgun / mk14 / semi-auto)
    -- Giữ lock giữa các tap liên tục thay vì drop + re-pick mỗi nhả cò
    -- lock hết hạn khi không tap lại trong khoảng này (giây)
    -- → đủ lớn để cover tap nhanh (~10 tap/s), đủ nhỏ để drop khi thực sự dừng bắn
    tapGapWindow  = 0.18,

    -- ADAPTIVE TRACK SPEED (boost trackSpeed khi địch đang chạy/dodge)
    -- finalSpeed = clamp(currentAimSpeed() + boost, 0, 1)
    -- boost = clamp(horizVelMag / adaptVelRef, 0, 1) * adaptMaxBoost
    adaptTrack    = true,
    adaptMaxBoost = 0.50,   -- [TrackFix] quadratic: 0.32+0.50=0.82 tại sprint full
    adaptVelRef   = 16,     -- [TrackFix] kick in sớm (22→16 studs/s)
    distBoostMax  = 18,     -- [v9.9.4] 25 → 18 studs: hẹp vùng close-range lại
    distMaxBoost  = 0.06,   -- [v9.9.4] 0.12 → 0.06: bonus nhẹ hơn tại point-blank, tránh overshoot

    -- ── VEHICLE HEAD TRACKER (v9.8) ──────────────────────────────────────────
    -- aimpart: Head.Position trực tiếp (live bone, không phải HRP + static offset)
    -- prediction BẬT cho vehicle, không fade-in (xe luôn đang di chuyển)
    -- tracker speed: smooth 0.88 — dán chặt đầu khi xe quẹo/tăng tốc/brake
    --
    -- predPos = headPos + vehicleVel * vehPredScale  (khi vel > vehPredMin)
    -- finalSpeed = vehTrackSpeed (không dùng adaptTrack hay flick cho vehicle)
    vehTrackSpeed = 0.88,   -- sticky smooth track: đủ cao để dán chặt mà không snap giật
                             -- công thức: alpha = 1-(1-0.88)^(dt*60) ≈ 0.9997 tại 60fps
                             -- → mỗi frame cam lao gần như 100% về head — cảm giác dính như keo
    vehPredScale  = 0.065,  -- [v9.9 FIX] vehicle prediction: 0.065s × 50stud/s ≈ 3.25 studs lead
                             -- 0.11 trước → 5.5 studs quá lớn, xe quẹo gấp = predict sai hướng → miss
                             -- 0.065 = đủ lead khi thẳng, không bị miss khi xe xoay
    vehPredMin    = 1.5,    -- studs/s: predict ngay khi xe bắt đầu lăn (không cần fade)
    headTopBias   = 0.0,    -- [v9.9 FIX] aim THẲNG TÂM head.Position (không bias lên)
                             -- 0.25 trước → overshoot 0.28 studs khi xe xóc/nhảy → miss
                             -- 0.0 = tâm hitbox head — stable nhất khi người ngồi trên xe

    esp = {
        box      = Color3.fromRGB(255, 255, 255),
        barBg    = Color3.fromRGB(30,  30,  30),
        barAlive = Color3.fromRGB(80,  220, 80),
        barLow   = Color3.fromRGB(220, 60,  60),
        thick    = 1,
    },

    fov_circle = {
        color = Color3.fromRGB(255, 255, 255),
        thick = 1,
        sides = 64,
    },
}

-- ═══════════════════════════════════════════════════════════
--  ANTI-AIM  (chỉ còn AD Strafe)
-- ═══════════════════════════════════════════════════════════
local AntiAim = {
    enabled          = true,
    pauseWhileFiring = false,

    adStrafeEnabled  = true,
    adStrafeMinTime  = 0.22,
    adStrafeMaxTime  = 0.38,

    _nextADStrafe = 0,
    _adDir        = 1,
    _adVec        = nil,
}

-- ═══════════════════════════════════════════════════════════
--  FOLIAGE
-- ═══════════════════════════════════════════════════════════
local FOLIAGE_KEYWORDS = {
    "feuillage", "bush", "grass", "leaf", "leaves",
    "foliage", "plant", "herbe", "buisson", "arbre", "tree",
}

local function isFoliage(part)
    if not part then return false end
    if part.CollisionGroup == "Feuillage" then return true end
    local m = part.Material
    if m == Enum.Material.Grass or m == Enum.Material.LeafyGrass then return true end
    local n = string.lower(part.Name)
    for i = 1, #FOLIAGE_KEYWORDS do
        if string.find(n, FOLIAGE_KEYWORDS[i], 1, true) then return true end
    end
    return false
end

-- ═══════════════════════════════════════════════════════════
--  W2S + UTILS
-- ═══════════════════════════════════════════════════════════
-- w2s trả về:
--   screenPos  = tọa độ pixel SAU khi apply stretchX  (dùng để VẼ ESP/box)
--   onScreen   = visible boolean từ Roblox
--   depth      = Z (> 0 = phía trước camera)
--   rawPos     = tọa độ pixel TRƯỚC stretchX          (dùng để tính khoảng cách FOV — không bị distort)
--
-- Bug cũ: pickTarget() tính screenDist từ fixedX (đã stretch)
--   → target sang bên: X compress lại 0.75× → screenDist nhỏ hơn thực tế
--   → FOV check pass ở chỗ sai, aim thấy tâm và địch hai chỗ khác nhau khi xa
local function w2s(pos)
    if typeof(pos) ~= "Vector3" then return nil, false, -1, nil end
    local ok, sp, vis = pcall(function()
        return camera:WorldToViewportPoint(pos)
    end)
    if not ok or not sp then return nil, false, -1, nil end
    local vp      = camera.ViewportSize
    local centerX = vp.X / 2
    local rawPos  = Vector2.new(math.round(sp.X), math.round(sp.Y))
    local fixedX  = centerX + (sp.X - centerX) / CFG.stretchX
    local drawPos = Vector2.new(math.round(fixedX), math.round(sp.Y))
    return drawPos, vis, sp.Z, rawPos
end

local function screenCenter()
    return camera.ViewportSize / 2
end

local function getCharParts(char)
    if not char then return nil, nil, nil end
    return char:FindFirstChild("HumanoidRootPart"),
           char:FindFirstChild("Head"),
           char:FindFirstChild("Humanoid")
end

local function isAlive(hum)
    return hum
        and hum.Health > 0
        and hum:GetState() ~= Enum.HumanoidStateType.Dead
end

-- ═══════════════════════════════════════════════════════════
--  LOS
-- ═══════════════════════════════════════════════════════════
local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLOS(targetPos, targetChar)
    if not CFG.wallCheck then return true end
    if typeof(targetPos) ~= "Vector3" then return false end

    local filterList = { workspace.Terrain }
    if lp.Character then
        table.insert(filterList, lp.Character)
    end

    if targetChar then
        local hum = targetChar:FindFirstChildOfClass("Humanoid")
        if hum and hum.SeatPart then
            local veh = hum.SeatPart:FindFirstAncestorOfClass("Model")
            if veh then table.insert(filterList, veh) end
        end
    end

    wallParams.FilterDescendantsInstances = filterList

    local origin    = camera.CFrame.Position
    local tv        = targetPos - origin
    local totalDist = tv.Magnitude
    if totalDist < 0.5 then return true end
    local dir       = tv.Unit

    local travelled = 0
    local maxIter   = CFG.foliageBypass and 12 or 1

    for _ = 1, maxIter do
        local remaining = totalDist - travelled - 0.4
        if remaining <= 0.1 then return true end

        local ok, hit = pcall(function()
            return workspace:Raycast(origin, dir * remaining, wallParams)
        end)
        if not ok or not hit then return true end

        if CFG.foliageBypass and isFoliage(hit.Instance) then
            travelled = travelled + hit.Distance + 0.15
            origin    = hit.Position + dir * 0.15
        else
            local hitInst = hit.Instance
            local hitChar = hitInst and hitInst:FindFirstAncestorOfClass("Model")
            if hitChar then
                for _, p in ipairs(Players:GetPlayers()) do
                    if p.Character == hitChar then return true end
                end
            end
            return false
        end
    end

    return true
end

-- ═══════════════════════════════════════════════════════════
--  2D BOX
-- ═══════════════════════════════════════════════════════════
local function getBoxPoints(char, hrp, head, hum)
    if not char or not hrp or not head or not hum then return nil end

    local topPos = head.Position + Vector3.new(0, head.Size.Y * 0.6, 0)

    local hipH = hum.HipHeight
    if hipH == 0 then
        hipH = (hum.RigType == Enum.HumanoidRigType.R6) and 2.5 or 2
    end
    local feetPos = hrp.Position - Vector3.new(0, hipH + hrp.Size.Y * 0.5, 0)

    local spTop,  _, depTop,  _ = w2s(topPos)
    local spFeet, _, depFeet, _ = w2s(feetPos)

    if not spTop  or depTop  <= 0 then return nil end
    if not spFeet or depFeet <= 0 then return nil end

    local boxH = math.abs(spFeet.Y - spTop.Y)
    if boxH < 2 then return nil end

    local boxW = boxH * 0.42
    local cx   = (spTop.X + spFeet.X) / 2

    return {
        tl   = Vector2.new(cx - boxW/2, spTop.Y),
        tr   = Vector2.new(cx + boxW/2, spTop.Y),
        bl   = Vector2.new(cx - boxW/2, spFeet.Y),
        br   = Vector2.new(cx + boxW/2, spFeet.Y),
        cx   = cx,
        boxH = boxH,
    }
end

-- ═══════════════════════════════════════════════════════════
--  AIM POSITION
--  Normal mode  → Neck (NeckRigAttachment hoặc fallback offset)
--  Vehicle mode → Head (HRP + head offset dump) + forceSpeed 1.0
--
--  Returns: aimPos (Vector3|nil), isInVehicle (bool), velForPred (Vector3)
--  velForPred = velocity dùng cho prediction:
--    vehicle → VehicleRoot.AssemblyLinearVelocity (ổn định hơn HRP passenger)
--    normal  → HRP.AssemblyLinearVelocity
-- ═══════════════════════════════════════════════════════════
local function getAimPos(head)
    if not head or not head.Parent then return nil, false, Vector3.zero end
    local char = head.Parent
    local hrp  = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")

    -- lấy velocity từ HRP assembly (fallback nếu không có VehicleRoot)
    local hrpVel = hrp and hrp.AssemblyLinearVelocity or Vector3.zero

    -- ── Vehicle detection: SeatPart phải là VehicleSeat (đang lái xe)
    local inVehicle = false
    local vehVel    = hrpVel  -- default: dùng HRP vel, override bằng VehicleRoot nếu có

    if hum and hum.SeatPart and hum.SeatPart:IsA("VehicleSeat") then
        inVehicle = true
        -- ── Lấy VehicleRoot.AssemblyLinearVelocity (ít jitter hơn HRP của passenger)
        --    VehicleRoot là BasePart gốc của xe, từ dump: vehModel:FindFirstChild("VehicleRoot")
        local vehModel = hum.SeatPart:FindFirstAncestorOfClass("Model")
        if vehModel then
            local vehRoot = vehModel:FindFirstChild("VehicleRoot")
            if vehRoot then
                vehVel = vehRoot.AssemblyLinearVelocity
            end
        end
    end

    if inVehicle then
        -- ── VEHICLE MODE: aim HEAD.Position trực tiếp (live bone) ────────────
        -- Lý do dùng head.Position thay vì HRP + static offset:
        --   1. Khi ngồi, R15 animation thay đổi — static offset không còn chính xác
        --   2. head.Position là WorldPosition của bone sau khi sim physics → luôn đúng
        --   3. HRP + headOffsetY * 0.9 (v9.7) undershoots -0.11 stud dưới tâm head
        --
        -- headTopBias: aim về phía trên tâm head (top of skull) — hitbox scan từ trên
        local headAimPos = head.Position + Vector3.new(0, head.Size.Y * CFG.headTopBias, 0)
        return headAimPos, true, vehVel
    end

    -- Normal mode: aim NECK (chính xác)
    -- Priority 1: NeckRigAttachment.WorldPosition trên UpperTorso (game-native joint)
    local upperTorso = char:FindFirstChild("UpperTorso")
    if upperTorso then
        local neckAtt = upperTorso:FindFirstChild("NeckRigAttachment")
        if neckAtt then
            return neckAtt.WorldPosition, false, hrpVel
        end
    end

    -- Priority 2: Fallback HRP + bone dump offset (top of UpperTorso = neck joint)
    -- [v11] Apply offset trong HRP local space (xoay theo CFrame của HRP)
    -- Bug cũ: cộng thẳng Vector3 world-space → khi địch xoay người, neck bị lệch khỏi cổ
    -- Fix: HRP.CFrame:PointToWorldSpace(localOffset) → luôn đúng dù địch quay hướng nào
    if hrp then
        local localOffset = Vector3.new(CFG.neckOffsetX, CFG.neckOffsetY, CFG.neckOffsetZ)
        return hrp.CFrame:PointToWorldSpace(localOffset), false, hrpVel
    end

    -- Priority 3: Head với offset âm (xuống dưới về phía cổ)
    return head.Position - Vector3.new(0, head.Size.Y * 0.3, 0), false, hrpVel
end

-- ═══════════════════════════════════════════════════════════
--  FIRE BUTTON
-- ═══════════════════════════════════════════════════════════
local isFiring = false

local function hookFireButton()
    local gui = lp:FindFirstChild("PlayerGui")
    if not gui then task.delay(2, hookFireButton) return end
    local btn = gui:FindFirstChild("MobileGui")
        and gui.MobileGui:FindFirstChild("Moved")
        and gui.MobileGui.Moved:FindFirstChild("Fire")
    if not btn then task.delay(2, hookFireButton) return end
    btn.InputBegan:Connect(function() isFiring = true  end)
    btn.InputEnded:Connect(function() isFiring = false end)
end

UserInputService.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.UserInputType == Enum.UserInputType.MouseButton1 then isFiring = true end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 then isFiring = false end
end)

task.defer(hookFireButton)

-- ═══════════════════════════════════════════════════════════
--  ALLY / CREW / CLAN SKIP SYSTEM
--  3 lớp bảo vệ — không aim vào đồng đội dù từ nguồn nào
--
--  Lớp 1 — CREW (collision group):
--    Game server set CollisionGroup="CrewChar" lên mọi Part của character
--    khi player join cùng crew → check HRP.CollisionGroup là reliable nhất
--
--  Lớp 2 — CLAN (ClanQuery RemoteFunction):
--    ReplicatedStorage.ClanQuery trả về clanId của từng player
--    Mình query clanId của lp một lần lúc load, rồi compare
--    Nếu query fail (không có clan) → clanId = nil → skip clan check
--
--  Lớp 3 — MANUAL ALLY (allySet):
--    Manual toggle từ GUI giống bên urban_ally
--    Nếu không có GUI → vẫn hoạt động qua allySet table
-- ═══════════════════════════════════════════════════════════

-- allySet: player → true (manual ally được toggle qua GUI hoặc tương lai)
local allySet = {}

-- myClanId: clanId của lp — nil nếu không có clan
local myClanId = nil

-- Query clan của bản thân một lần lúc load
-- ClanQuery:InvokeServer("GetMyClan") → {id=..., name=...} hoặc nil
task.spawn(function()
    local ok, result = pcall(function()
        local cq = ReplicatedStorage:FindFirstChild("ClanQuery")
        if not cq then return nil end
        return cq:InvokeServer("GetMyClan")
    end)
    if ok and type(result) == "table" and result.id then
        myClanId = result.id
    end
end)

-- getClanId(player): query clanId của player khác
-- cache kết quả để không spam RemoteFunction mỗi frame
local clanCache    = {}   -- player → {id, fetchedAt}
local CLAN_TTL     = 30   -- seconds: re-query sau 30s (member có thể rời clan)

local function getClanId(player)
    local now    = os.clock()
    local cached = clanCache[player]
    if cached and (now - cached.fetchedAt) < CLAN_TTL then
        return cached.id
    end
    -- fetch async để không block aim loop
    task.spawn(function()
        local ok, result = pcall(function()
            local cq = ReplicatedStorage:FindFirstChild("ClanQuery")
            if not cq then return nil end
            return cq:InvokeServer("GetPlayerClan", player.UserId)
        end)
        local id = (ok and type(result) == "table") and result.id or nil
        clanCache[player] = { id=id, fetchedAt=os.clock() }
    end)
    -- trả về cached cũ trong khi đang fetch, nil nếu chưa có lần nào
    return cached and cached.id or nil
end

-- isCrewMate(char): check CollisionGroup "CrewChar" trên HRP
-- game server set cái này → không thể spoof từ client
local function isCrewMate(char)
    if not char then return false end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end
    return hrp.CollisionGroup == "CrewChar"
end

-- isClanMate(player): same clan check qua cached ClanQuery
local function isClanMate(player)
    if not myClanId then return false end          -- mình không có clan
    local theirId = getClanId(player)
    if not theirId then return false end
    return theirId == myClanId
end

-- isAllyPlayer(player, char): tổng hợp 3 lớp
local function isAllyPlayer(player, char)
    if allySet[player]      then return true end   -- Lớp 3: manual
    if isCrewMate(char)     then return true end   -- Lớp 1: crew collision group
    if isClanMate(player)   then return true end   -- Lớp 2: clan query
    return false
end

-- cleanup cache khi player rời game
Players.PlayerRemoving:Connect(function(pl)
    clanCache[pl] = nil
    allySet[pl]   = nil
end)

-- ═══════════════════════════════════════════════════════════
--  HARD LOCK + FOV STRICT + FLICK STATE
-- ═══════════════════════════════════════════════════════════
local lockedTarget  = nil
local wasFireing    = false
local lockExpireAt  = 0
local smoothedVel   = Vector3.zero

local flickState = {
    active  = false,
    startAt = 0,
}

local function isTargetValid(head)
    if not head or not head.Parent then return false end
    local char = head.Parent
    -- drop lock ngay nếu target trở thành ally mid-lock
    for _, pl in ipairs(Players:GetPlayers()) do
        if pl.Character == char then
            if isAllyPlayer(pl, char) then return false end
            break
        end
    end
    local _, _, hum = getCharParts(char)
    if not isAlive(hum) then return false end
    if (camera.CFrame.Position - head.Position).Magnitude > CFG.aimDist then return false end
    local sp, onScreen, depth, _ = w2s(head.Position)
    if not sp or not onScreen or depth <= 0 then return false end
    if not hasLOS(head.Position, char) then return false end
    return true
end

-- pickTarget trả về (head, screenDist) — screenDist để quyết định flick
local function pickTarget()
    local center  = screenCenter()
    local camPos  = camera.CFrame.Position

    local bestHead = nil
    local bestDist = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if player == lp then continue end
        -- skip crew / clan / manual ally
        local char = player.Character
        if not char then continue end
        if isAllyPlayer(player, char) then continue end
        local hrp, head, hum = getCharParts(char)
        if not head or not hum or not hrp then continue end
        if not isAlive(hum) then continue end

        if (camPos - head.Position).Magnitude > CFG.aimDist then continue end

        local sp, onScreen, depth, rawSp = w2s(head.Position)
        if not sp or not onScreen or depth <= 0 then continue end

        local rawPt      = rawSp or sp
        local screenDist = (rawPt - center).Magnitude
        if screenDist > CFG.fov then continue end

        if not hasLOS(head.Position, char) then continue end

        if screenDist < bestDist then
            bestDist = screenDist
            bestHead = head
        end
    end

    return bestHead, bestDist
end

-- ═══════════════════════════════════════════════════════════
--  ESP POOL
-- ═══════════════════════════════════════════════════════════
local espPool = {}

local function mkLine(color, thick)
    local l = Drawing.new("Line")
    l.Visible   = false
    l.Color     = color
    l.Thickness = thick or 1
    l.ZIndex    = 2
    return l
end

local function getBundle(player)
    if espPool[player] then return espPool[player] end
    local E = CFG.esp
    local b = {
        box = {
            mkLine(E.box, E.thick),
            mkLine(E.box, E.thick),
            mkLine(E.box, E.thick),
            mkLine(E.box, E.thick),
        },
        dist    = Drawing.new("Text"),
        barBg   = mkLine(E.barBg,    2),
        barFill = mkLine(E.barAlive, 2),
    }
    b.dist.Center  = true
    b.dist.Outline = true
    b.dist.Size    = 11
    b.dist.Color   = Color3.fromRGB(255, 255, 255)
    b.dist.Font    = 2
    espPool[player] = b
    return b
end

local function hideBundle(b)
    for _, l in ipairs(b.box) do l.Visible = false end
    b.dist.Visible    = false
    b.barBg.Visible   = false
    b.barFill.Visible = false
end

local function removeBundle(player)
    local b = espPool[player]
    if not b then return end
    for _, l in ipairs(b.box) do l:Remove() end
    b.dist:Remove()
    b.barBg:Remove()
    b.barFill:Remove()
    espPool[player] = nil
end

Players.PlayerRemoving:Connect(removeBundle)

-- ═══════════════════════════════════════════════════════════
--  FOV CIRCLE
-- ═══════════════════════════════════════════════════════════
local fovCircle = Drawing.new("Circle")
fovCircle.Visible   = true
fovCircle.Color     = CFG.fov_circle.color
fovCircle.Thickness = CFG.fov_circle.thick
fovCircle.Filled    = false
fovCircle.NumSides  = CFG.fov_circle.sides
fovCircle.Radius    = CFG.fov
fovCircle.ZIndex    = 1

-- ═══════════════════════════════════════════════════════════
--  ANTI-AIM STATUS
-- ═══════════════════════════════════════════════════════════
local aaStatus = Drawing.new("Text")
aaStatus.Size     = 15
aaStatus.Color    = Color3.fromRGB(80, 255, 120)
aaStatus.Outline  = true
aaStatus.Center   = false
aaStatus.Position = Vector2.new(10, 10)
aaStatus.Font     = 2
aaStatus.ZIndex   = 10
aaStatus.Visible  = true
aaStatus.Text     = "🛡️ ANTI-AIM: AC-SAFE FLICK | v12.0 | AimDriftFix⚡CrewSkip⚡ClanSkip⚡AllySkip⚡TrackFix⚡VehFix"

-- ═══════════════════════════════════════════════════════════
--  ANTI-AIM TICK  (AD Strafe only)
-- ═══════════════════════════════════════════════════════════
local function tickAntiAim(dt)
    if not AntiAim.enabled then return end
    if AntiAim.pauseWhileFiring and isFiring then return end

    local char = lp.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return end
    if hum.SeatPart then return end

    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local st = hum:GetState()
    if st == Enum.HumanoidStateType.Dead
    or st == Enum.HumanoidStateType.Physics
    or st == Enum.HumanoidStateType.Ragdoll then return end

    local now = os.clock()

    if AntiAim.adStrafeEnabled and isFiring and CFG.aimOn and lockedTarget then
        if now >= AntiAim._nextADStrafe or not AntiAim._adVec then
            AntiAim._nextADStrafe = now
                + math.random() * (AntiAim.adStrafeMaxTime - AntiAim.adStrafeMinTime)
                + AntiAim.adStrafeMinTime
            AntiAim._adDir = -AntiAim._adDir
            local right = camera.CFrame.RightVector
            local flatRight = Vector3.new(right.X, 0, right.Z)
            if flatRight.Magnitude > 0.01 then
                AntiAim._adVec = flatRight.Unit * AntiAim._adDir
            end
        end
        if AntiAim._adVec then
            hum:Move(AntiAim._adVec, false)
        end
        return
    end

    AntiAim._adVec = nil
end

-- ═══════════════════════════════════════════════════════════
--  SMOOTH AIM (adaptive: flick khi xa → track khi gần)
--  + micro-noise để tay run tự nhiên
--  + CHỈ lerp ROTATION, giữ nguyên Position camera
--
--  forceSpeed: nếu truyền vào, dùng thay vì currentAimSpeed()
--              = 1.0 khi target đang lái VehicleSeat (snap tức thì)
-- ═══════════════════════════════════════════════════════════
local _aimNoise = math.random() * 1000

local function currentAimSpeed()
    if flickState.active then
        local elapsed = os.clock() - flickState.startAt
        if elapsed >= CFG.flickEaseTime then
            flickState.active = false
            return CFG.trackSpeed
        end
        -- quadratic ease-out: bắt đầu ~flickSpeed, giảm dần về trackSpeed
        local t       = elapsed / CFG.flickEaseTime
        local easeOut = (1 - t) * (1 - t)
        return CFG.trackSpeed + (CFG.flickSpeed - CFG.trackSpeed) * easeOut
    end
    return CFG.trackSpeed
end

-- computeAimSpeed: lấy speed cuối cùng để truyền vào smoothLookAt
-- vehicle → vehTrackSpeed (smooth sticky: 0.88, không dùng flick/adaptTrack)
--            tại 60fps: alpha = 1-(1-0.88)^(dt*60) ≈ 0.9997 → gần như snap nhưng mượt
-- normal  → currentAimSpeed() + adaptive boost theo vận tốc ngang địch
local function computeAimSpeed(inVehicle, horizVelMag, targetDist)
    if inVehicle then return CFG.vehTrackSpeed end
    local base = currentAimSpeed()
    if not CFG.adaptTrack then return base end
    -- [TrackFix] Quadratic: gentle at low speed, aggressive at high speed
    -- t^2 curve: 0→0, 0.5→0.125, 1→1  (harsh upper end = bám chặt khi sprint)
    local t     = math.clamp(horizVelMag / CFG.adaptVelRef, 0, 1)
    local boost = t * t * CFG.adaptMaxBoost
    -- [TrackFix] Close-range distance bonus:
    --   địch < 25 studs → angular vel rất cao → cần trackSpeed cao hơn nhiều
    --   bonus = lerp(0→distMaxBoost) khi dist từ distBoostMax→0
    local distBonus = 0
    if targetDist then
        distBonus = math.clamp(1 - targetDist / CFG.distBoostMax, 0, 1) * CFG.distMaxBoost
    end
    return math.clamp(base + boost + distBonus, 0, 1)
end

local function smoothLookAt(targetPos, dt, forceSpeed)
    local camCF  = camera.CFrame
    local camPos = camCF.Position

    -- [v11] micro-random offset theo camera-local right/up vector
    -- Bug cũ: Vector3.new(nx, ny, 0) = world XY cứng
    --   → khi camera nhìn chéo / sang bên, trục Y world ≠ trục Y screen
    --   → noise push aim theo hướng sai, lệch nhiều khi xa địch (góc lớn)
    -- Fix: project noise lên camCF.RightVector và camCF.UpVector (screen-aligned)
    local t  = os.clock()
    local nx = math.noise(t * 1.7, _aimNoise)       * 0.006
    local ny = math.noise(t * 2.1, _aimNoise + 100) * 0.006
    local humanizedPos = targetPos
        + camCF.RightVector * nx
        + camCF.UpVector    * ny

    -- target rotation: nhìn từ camPos về neck / head
    local targetCF = CFrame.lookAt(camPos, humanizedPos, Vector3.new(0, 1, 0))

    -- tốc độ: forceSpeed override (vehicle snap) hoặc adaptive flick/track
    local speed = forceSpeed or currentAimSpeed()
    local alpha = 1 - (1 - speed) ^ (dt * 60)
    alpha = math.clamp(alpha, 0, 1)

    -- CHỈ lerp rotation, giữ Position để tránh camera bị kéo
    local lerpedRot = camCF.Rotation:Lerp(targetCF.Rotation, alpha)
    camera.CFrame   = CFrame.new(camPos) * lerpedRot
end

-- ═══════════════════════════════════════════════════════════
--  MAIN LOOP
-- ═══════════════════════════════════════════════════════════
RunService:BindToRenderStep("AimbotESP", Enum.RenderPriority.Camera.Value + 1, function(dt)
    pcall(function()

        local now = os.clock()

        tickAntiAim(dt)

        fovCircle.Radius   = CFG.fov
        fovCircle.Position = screenCenter()
        fovCircle.Visible  = CFG.aimOn

        local fireStarted = isFiring and not wasFireing
        local fireEnded   = not isFiring and wasFireing

        -- ── FIRE / FLICK LOGIC ──
        --
        -- TAP-FIRE PERSIST (v9.9+): shotgun / mk14 / semi-auto
        -- Vấn đề cũ: fireEnded → drop lock → fireStarted → pick lại → flick lại
        -- Mỗi tap là một chu kỳ flick từ đầu → aimbot giật vô giật ra
        --
        -- Fix: khi nhả cò KHÔNG drop lock ngay — set lockExpireAt = now + tapGapWindow
        -- Nếu tap lại trong window (< 0.18s) → tiếp tục lock cũ, KHÔNG flick lại
        -- Lock thực sự expire khi: không tap lại đủ lâu, hoặc target invalid
        if fireEnded then
            -- Nhả cò: set expire timer thay vì drop lock ngay
            if lockedTarget then
                lockExpireAt = now + CFG.tapGapWindow
            end
            flickState.active = false
        end

        if isFiring then
            if fireStarted then
                if lockedTarget and now < lockExpireAt and isTargetValid(lockedTarget) then
                    -- Tap tiếp theo trong window: giữ lock cũ, KHÔNG flick lại
                    lockExpireAt      = 0
                    flickState.active = false
                else
                    -- Lock expire hoặc không có: pick target mới
                    lockExpireAt = 0
                    smoothedVel  = Vector3.zero  -- reset EMA, tránh stale vel từ target cũ
                    local t, sdist = pickTarget()
                    lockedTarget   = t
                    if lockedTarget then
                        if sdist and sdist > CFG.flickThreshold then
                            flickState.active  = true
                            flickState.startAt = os.clock()
                        else
                            flickState.active  = false
                        end
                    end
                end
            elseif lockedTarget then
                -- Giữa burst: validate liên tục, không re-pick
                if not isTargetValid(lockedTarget) then
                    lockedTarget      = nil
                    flickState.active = false
                    lockExpireAt      = 0
                end
            end
        else
            -- Không firing: expire lock nếu window đã qua
            if lockExpireAt > 0 and now >= lockExpireAt then
                lockedTarget = nil
                lockExpireAt = 0
            end
            flickState.active = false
        end
        wasFireing = isFiring

        -- ── SMOOTH AIM / FLICK + PREDICTION + ADAPTIVE SPEED ──
        --
        -- getAimPos → (aimPos, inVehicle, velForPred)
        --   vehicle: velForPred = VehicleRoot.AssemblyLinearVelocity (ổn định)
        --   normal:  velForPred = HRP.AssemblyLinearVelocity
        --
        -- [1] Velocity prediction:
        --   VEHICLE: predPos = headPos + vehicleVel * vehPredScale
        --            → áp dụng ngay khi vel > vehPredMin (không fade-in)
        --            → xe luôn chạy → không cần noise guard như khi đứng yên
        --   NORMAL:  predPos = aimPos + hrpVel * (velPredScale * fadeFactor)
        --            → fadeFactor = clamp(velMag / velPredFadeIn, 0, 1)
        --            → fade về 0 khi đứng yên, full lead khi chạy
        --
        -- [2] Adaptive speed:
        --   VEHICLE: vehTrackSpeed = 0.88 (sticky smooth, không dùng flick/adapt)
        --   NORMAL:  currentAimSpeed() + adaptive boost theo vận tốc ngang
        if CFG.aimOn and isFiring and lockedTarget then
            local selfChar = lp.Character
            if selfChar then
                local _, _, selfHum = getCharParts(selfChar)
                if isAlive(selfHum) then
                    local aimPos, inVehicle, velForPred = getAimPos(lockedTarget)
                    if aimPos then
                        -- [1] Velocity prediction — vehicle và normal path tách biệt
                        local predPos = aimPos
                        if inVehicle and velForPred then
                            -- VEHICLE: predict raw vel (xe không AD spam), no EMA
                            local velMag = velForPred.Magnitude
                            if velMag > CFG.vehPredMin then
                                predPos = aimPos + velForPred * CFG.vehPredScale
                            end
                        elseif not inVehicle and velForPred then
                            -- NORMAL: [TrackFix] One-sided EMA
                            -- vel TĂNG → attack alpha=0.45 → catch up nhanh khi địch sprint
                            -- vel GIẢM → decay alpha=0.18 → không jerk khi địch AD spam
                            local rawMag = velForPred.Magnitude
                            local ema    = rawMag > smoothedVel.Magnitude and 0.45 or CFG.velSmooth
                            smoothedVel  = smoothedVel:Lerp(velForPred, ema)

                            local velMag = smoothedVel.Magnitude
                            local fade   = math.clamp(velMag / CFG.velPredFadeIn, 0, 1)
                            -- [TrackFix] Dynamic lead: scales 1×→1.4× with speed
                            -- địch sprint 22stud/s: 0.085×1.4×1.0=0.119s lead ≈ 2.6 studs
                            local speedRatio   = math.clamp(velMag / CFG.adaptVelRef, 0, 1.5)
                            local dynPredScale = CFG.velPredScale * (1 + speedRatio * 0.4)
                            local leadDist     = dynPredScale * fade
                            if leadDist > 0 then
                                predPos = aimPos + smoothedVel * leadDist
                            end
                        end

                        -- [2] Adaptive speed: vel boost + close-range distance bonus
                        local horizMag   = velForPred
                            and Vector3.new(velForPred.X, 0, velForPred.Z).Magnitude
                            or  0
                        local targetDist = (camera.CFrame.Position - aimPos).Magnitude
                        local aimSpeed   = computeAimSpeed(inVehicle, horizMag, targetDist)

                        smoothLookAt(predPos, dt, aimSpeed)
                    end
                end
            end
        end

        -- ── ESP LOOP ──
        local myChar = lp.Character
        local myHRP  = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local myPos  = myHRP and myHRP.Position
        local camPos = camera.CFrame.Position

        for _, player in ipairs(Players:GetPlayers()) do
            if player == lp then continue end

            local char = player.Character
            if not char then
                if espPool[player] then removeBundle(player) end
                continue
            end

            local hrp, head, hum = getCharParts(char)
            local alive = hrp and head and hum and isAlive(hum)

            if not alive or not CFG.espOn then
                if espPool[player] then hideBundle(espPool[player]) end
                continue
            end

            local dist = math.floor((camPos - hrp.Position).Magnitude)
            if dist > (CFG.espDist + 15) then
                if espPool[player] then hideBundle(espPool[player]) end
                continue
            end

            local box = getBoxPoints(char, hrp, head, hum)
            if not box then
                if espPool[player] then hideBundle(espPool[player]) end
                           continue
            end

            local b = getBundle(player)
            local E = CFG.esp

            b.box[1].From = box.tl ; b.box[1].To = box.tr
            b.box[2].From = box.bl ; b.box[2].To = box.br
            b.box[3].From = box.tl ; b.box[3].To = box.bl
            b.box[4].From = box.tr ; b.box[4].To = box.br
            for _, l in ipairs(b.box) do
                l.Color   = E.box
                l.Visible = true
            end

            local displayDist = myPos
                and math.floor((myPos - hrp.Position).Magnitude)
                or  dist

            b.dist.Text     = displayDist .. "m"
            b.dist.Position = Vector2.new(box.cx, box.br.Y + 2)
            b.dist.Visible  = true

            local hp   = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            local barX = box.tl.X - 4

            b.barBg.From    = Vector2.new(barX, box.tl.Y)
            b.barBg.To      = Vector2.new(barX, box.br.Y)
            b.barBg.Color   = E.barBg
            b.barBg.Visible = true

            b.barFill.From    = Vector2.new(barX, box.br.Y)
            b.barFill.To      = Vector2.new(barX, box.br.Y - box.boxH * hp)
            b.barFill.Color   = hp > 0.4 and E.barAlive or E.barLow
            b.barFill.Visible = true
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
--  BOOT
-- ═══════════════════════════════════════════════════════════
task.spawn(function()
    repeat task.wait() until lp:FindFirstChild("PlayerGui")
    print("[Hood Mobile v12.0 AIM-DRIFT-FIX+CREW/CLAN/ALLY-SKIP] loaded")
    print("  → Tap-fire persist: lockExpireAt window=" .. CFG.tapGapWindow .. "s (shotgun/mk14 fix)")
    print("  → Aimpart: Neck (NeckRigAttachment) / Head.Position LIVE khi lái xe")
    print("  → Vehicle tracker: speed=" .. CFG.vehTrackSpeed
        .. " | pred=" .. CFG.vehPredScale .. "s lead | predMin>" .. CFG.vehPredMin .. "studs/s")
    print("  → Vehicle vel source: VehicleRoot.AssemblyLinearVelocity (fallback HRP)")
    print("  → Head aim bias: " .. CFG.headTopBias .. " (0.0=center head, v9.9 fix)")
    print("  → Normal prediction: " .. CFG.velPredScale .. "s lead | fade<" .. CFG.velPredFadeIn .. "studs/s (close-range safe)")
    print("  → Adaptive track: +" .. CFG.adaptMaxBoost .. " boost tại " .. CFG.adaptVelRef .. "studs/s sprint")
    print("  → Foliage bypass: ON")
    print("  → AC-safe aim: flick=" .. CFG.flickSpeed
        .. " → track=" .. CFG.trackSpeed
        .. " | flick>=" .. CFG.flickThreshold .. "px")
    print("  → Anti-Aim: AD Strafe only")
    print("  → AutoJump / AutoCrouch: REMOVED")
end)
