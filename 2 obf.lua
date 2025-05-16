return [[
    
    Window:Notify({
        Title = "Hand Visual",
        Description = "Hand Visual  - ",
        Lifetime = 5
    })
    
    
    pcall(function()
        if PlayerHandSection and PlayerHandSection.Objects and 
           PlayerHandSection.Objects["EnableHandSkin"] and 
           type(PlayerHandSection.Objects["EnableHandSkin"].Set) == "function" then
            PlayerHandSection.Objects["EnableHandSkin"]:Set(false)
        end
    end)
end

sections.WorldESP:Header({
    Text = "World ESP Settings"
})
sections.WorldESP:Toggle({
    Name = "Enable World ESP",
    Default = false,
    Callback = function(value)
        WorldESP.Enabled = value
        WorldESP.KeyESPEnabled = value  
        
        if value then
            if not WorldESP.RenderThreadActive then
                WorldESP.RenderThreadActive = true
                
                
                task.spawn(function()
                    local lastFullContainerScan = 0
                    
                    while WorldESP.RenderThreadActive do
                        if WorldESP.Enabled then
                            
                            if WorldESP.KeyESPEnabled then
                                scanForKeys()
                            end
                            
                            local currentTime = tick()
                            
                            if WorldESP.ContainerESPEnabled then
                                if currentTime - lastFullContainerScan > 15 then 
                                    scanForContainers()
                                    lastFullContainerScan = currentTime
                                end
                            end
                            
                            if WorldESP.DroppedItemsESPEnabled then
                                scanForDroppedItems()
                            end
                        end
                        
                        
                        wait(3)
                    end
                end)
                
                
                coroutine.wrap(function()
                    local camera = Workspace.CurrentCamera
                    
                    while WorldESP.RenderThreadActive do
                        local cameraPos = camera.CFrame.Position
                        local hasActiveESP = false
                        local maxVisibleItems = 30 
                        local visibleCount = 0
                        
                        
                        for instance, data in pairs(WorldESP.TrackedItems) do
                            
                            if not instance or not instance.Parent or 
                               (data.IsKey and not WorldESP.KeyESPEnabled) or 
                               (data.IsContainer and not WorldESP.ContainerESPEnabled) or
                               (data.IsDroppedItem and not data.IsKey and not WorldESP.DroppedItemsESPEnabled) then
                                if data.Drawing and data.Drawing.Visible then
                                    data.Drawing.Visible = false
                                end
                                continue
                            end
                            
                            if visibleCount >= maxVisibleItems then
                                if data.Drawing and data.Drawing.Visible then
                                    data.Drawing.Visible = false
                                end
                                continue
                            end
                            
                            hasActiveESP = true
                            
                            
                            if not data.Drawing then
                                data.Drawing = getDrawingFromPool()
                            end
                            
                            
                            local objectPos
                            local trackPart = data.TrackPart
                            
                            
                            if not trackPart or not trackPart.Parent then
                                local success, newTrackPart = pcall(function()
                                    return instance.PrimaryPart or 
                                          (instance:IsA("Model") and instance:FindFirstChildWhichIsA("BasePart", true)) or 
                                          (instance:IsA("BasePart") and instance) or nil
                                end)
                                
                                if success and newTrackPart then
                                    trackPart = newTrackPart
                                    data.TrackPart = trackPart
                                else
                                    if data.Drawing and data.Drawing.Visible then
                                        data.Drawing.Visible = false
                                    end
                                    continue
                                end
                            end
                            
                            
                            local success, pos = pcall(function()
                                return trackPart.Position
                            end)
                            
                            if not success then
                                if data.Drawing and data.Drawing.Visible then
                                    data.Drawing.Visible = false
                                end
                                continue
                            end
                            
                            objectPos = pos
                            
                            
                            data.CachedPosition = objectPos
                            data.LastUpdateTime = tick()
                            
                            
                            local distance = (cameraPos - objectPos).Magnitude
                            
                            if distance > WorldESP.MaxDistance then
                                if data.Drawing and data.Drawing.Visible then
                                    data.Drawing.Visible = false
                                end
                                continue
                            end
                            
                            
                            local screenPoint, isOnScreen = nil, false
                            
                            success, screenPoint = pcall(function()
                                local point = camera:WorldToViewportPoint(objectPos)
                                return point
                            end)
                            
                            if success then
                                
                                isOnScreen = screenPoint.Z > 0 and 
                                             screenPoint.X > 0 and screenPoint.X < camera.ViewportSize.X and
                                             screenPoint.Y > 0 and screenPoint.Y < camera.ViewportSize.Y
                            end
                            
                            
                            
                            
                            if not success or not isOnScreen then
                                if data.Drawing and data.Drawing.Visible then
                                    data.Drawing.Visible = false
                                end
                                continue
                            end
                            
                            
                            data.Drawing.Size = WorldESP.TextSize
                            data.Drawing.Color = WorldESP.TextColor  
                            data.Drawing.Transparency = WorldESP.TextTransparency
                            
                            
                            local xPos = math.clamp(screenPoint.X, 5, camera.ViewportSize.X - 5)
                            local yPos = math.clamp(screenPoint.Y - 25, 5, camera.ViewportSize.Y - 5)
                            data.Drawing.Position = Vector2.new(xPos, yPos)
                            
                            
                            local displayText = data.DisplayName
                            
                            
                            displayText = displayText:gsub("?", "")
                            displayText = displayText:gsub("[^%a%d%s_%-:%.%[%]]", "")
                            
                            
                            if displayText:match("^%s*$") or displayText == ":" then
                                if data.IsContainer then
                                    displayText = "Container"
                                elseif data.IsKey then
                                    displayText = "Key"
                                elseif data.IsDroppedItem then
                                    displayText = "Item"
                                else
                                    displayText = "Object"
                                end
                            end
                            
                            
                            
                            
                            
                            if data.IsHiddenCache then
                                
                                data.Drawing.Text = displayText .. " [" .. math.floor(distance) .. "m]"
                            else
                                data.Drawing.Text = displayText .. " [" .. math.floor(distance) .. "m]"
                            end
                            
                            data.Drawing.Visible = true
                            
                            visibleCount = visibleCount + 1
                        end
                        
                        
                        local currentTime = tick()
                        if currentTime - WorldESP.LastCleanup > 5 then
                            local invalidItems = {}
                            
                            for instance, data in pairs(WorldESP.TrackedItems) do
                                if not instance or not instance.Parent then
                                    if data.Drawing then
                                        returnDrawingToPool(data.Drawing)
                                    end
                                    table.insert(invalidItems, instance)
                                end
                            end
                            
                            for _, instance in ipairs(invalidItems) do
                                WorldESP.TrackedItems[instance] = nil
                            end
                            
                            WorldESP.LastCleanup = currentTime
                        end
                        
                        
                        if hasActiveESP then
                            RunService.RenderStepped:Wait()
                        else
                        wait(0.1)
                        end
                    end
                end)()
            end
        else
            
            WorldESP.RenderThreadActive = false
            
            
            for _, data in pairs(WorldESP.TrackedItems) do
                if data.Drawing then
                    returnDrawingToPool(data.Drawing)
                    data.Drawing = nil
                                end
                            end
            
            
            WorldESP.TrackedItems = {}
        end
    end
}, "EnableWorldESP")

sections.WorldESP:Toggle({
    Name = "Container ESP",
    Default = false,
    Callback = function(value)
        WorldESP.ContainerESPEnabled = value
        
        
        if WorldESP.Enabled and WorldESP.ContainerESPEnabled then
            scanForContainers()
        end
        
        
        if not value then
            for _, data in pairs(WorldESP.TrackedItems) do
                if data.IsContainer and data.Drawing then
                    data.Drawing.Visible = false
                end
            end
        end
    end
}, "ContainerESP")

sections.WorldESP:Toggle({
    Name = "Dropped Items ESP",
    Default = false,
    Callback = function(value)
        WorldESP.DroppedItemsESPEnabled = value
        
        
        if WorldESP.Enabled and WorldESP.DroppedItemsESPEnabled then
            scanForDroppedItems()
        end
        
        
        if not value then
            for _, data in pairs(WorldESP.TrackedItems) do
                if data.IsDroppedItem and data.Drawing then
                    data.Drawing.Visible = false
                end
            end
        end
    end
}, "DroppedItemsESP")

sections.WorldESP:Slider({
    Name = "Max Distance",
    Default = 500,
    Minimum = 100,
    Maximum = 2000,
    Precision = 2,
    Callback = function(value)
        WorldESP.MaxDistance = value
    end
}, "WorldESPMaxDistance")

sections.WorldESP:Slider({
    Name = "Text Size",
    Default = 14,
    Minimum = 8,
    Maximum = 24,
    Precision = 2,
    Callback = function(value)
        WorldESP.TextSize = value
        
        
        for _, data in pairs(WorldESP.TrackedItems) do
            if data.Drawing then
                data.Drawing.Size = value
            end
        end
        
        
        for _, drawing in ipairs(WorldESP.DrawingPool) do
            drawing.Size = value
        end
    end
}, "WorldESPTextSize")

sections.WorldESP:Colorpicker({
    Name = "Text Color",
    Default = WorldESP.TextColor,
    Alpha = 0,
    Callback = function(color)
        WorldESP.TextColor = color
        
        
        for _, data in pairs(WorldESP.TrackedItems) do
            if data.Drawing then
                data.Drawing.Color = WorldESP.TextColor
            end
        end
        
        
        for _, drawing in ipairs(WorldESP.DrawingPool) do
            drawing.Color = WorldESP.TextColor
        end
    end
}, "WorldESPTextColor")

sections.WorldESP:Slider({
    Name = "Text Transparency",
    Default = 0.3, 
    Minimum = 0,
    Maximum = 0.9,
    Precision = 2,
    Callback = function(value)
        WorldESP.TextTransparency = value
        
        
        for _, data in pairs(WorldESP.TrackedItems) do
            if data.Drawing then
                data.Drawing.Transparency = value
            end
        end
        
        
        for _, drawing in ipairs(WorldESP.DrawingPool) do
            drawing.Transparency = value
        end
    end
}, "WorldESPTextTransparency")

sections.WorldVisual:Header({
    Text = "Lighting Settings"
})

sections.WorldVisual:Toggle({
    Name = "Full Bright",
    Default = false,
    Callback = function(value)
        if value then
            _G.OriginalLightingSettings = {
                Brightness = Lighting.Brightness,
                Ambient = Lighting.Ambient,
                OutdoorAmbient = Lighting.OutdoorAmbient,
                GlobalShadows = Lighting.GlobalShadows
            }
            
            Lighting.Brightness = 2
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(199, 199, 199)
            Lighting.OutdoorAmbient = Color3.fromRGB(199, 199, 199)
        else
            if _G.OriginalLightingSettings then
                Lighting.Brightness = _G.OriginalLightingSettings.Brightness
                Lighting.Ambient = _G.OriginalLightingSettings.Ambient
                Lighting.OutdoorAmbient = _G.OriginalLightingSettings.OutdoorAmbient
                Lighting.GlobalShadows = _G.OriginalLightingSettings.GlobalShadows
                
                _G.OriginalLightingSettings = nil
            end
        end
    end
}, "FullBright")

sections.WorldVisual:Toggle({
    Name = "X-Ray",
    Default = false,
    Callback = function(value)
        if value then
            _G.XRayOriginalProperties = {}
            
            for _, obj in pairs(Workspace:GetDescendants()) do
                if obj:IsA("BasePart") and not obj:IsA("Terrain") then
                    _G.XRayOriginalProperties[obj] = {
                        Transparency = obj.Transparency,
                        Material = obj.Material,
                        Color = obj.Color
                    }
                    
                    obj.Transparency = 0.75
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end
            
            _G.XRayConnection = Workspace.DescendantAdded:Connect(function(obj)
                if obj:IsA("BasePart") and not obj:IsA("Terrain") then
                    _G.XRayOriginalProperties[obj] = {
                        Transparency = obj.Transparency,
                        Material = obj.Material,
                        Color = obj.Color
                    }
                    
                    obj.Transparency = 0.75
                    obj.Material = Enum.Material.SmoothPlastic
                end
            end)
        else
            if _G.XRayOriginalProperties then
                for obj, props in pairs(_G.XRayOriginalProperties) do
                    if obj and obj:IsA("BasePart") then
                        for prop, value in pairs(props) do
                            pcall(function() obj[prop] = value end)
                            end
                        end
                    end
                _G.XRayOriginalProperties = nil
            end
            
            if _G.XRayConnection then
                _G.XRayConnection:Disconnect()
                _G.XRayConnection = nil
            end
        end
    end
}, "XRay")

sections.WorldVisual:Header({
    Text = "Foliage Settings"
})

sections.WorldVisual:Toggle({
    Name = "Hide Leaves",
    Default = false,
    Callback = function(value)
        if value then
            if not _G.OriginalLeavesTransparency then
                _G.OriginalLeavesTransparency = {}
            end
            
            local function processLeafObject(obj)
                if not obj or not obj:IsA("MeshPart") or not obj:FindFirstChild("SurfaceAppearance") then
                    return
                end
                
                local current = obj
                while current do
                    if current == workspace.Camera then
                        return
                    end
                    current = current.Parent
                end
                
                if not _G.OriginalLeavesTransparency[obj] then
                    _G.OriginalLeavesTransparency[obj] = obj.Transparency
                end
                
                obj.Transparency = 1
            end
            
            for _, obj in pairs(workspace:GetDescendants()) do
                pcall(function()
                    processLeafObject(obj)
                end)
            end
            
            if _G.LeavesAddedConnection then
                _G.LeavesAddedConnection:Disconnect()
            end
            
            _G.LeavesAddedConnection = workspace.DescendantAdded:Connect(function(obj)
                pcall(function()
                    task.wait()
                    processLeafObject(obj)
                end)
            end)
            
            if _G.LeavesScanConnection then
                _G.LeavesScanConnection:Disconnect()
            end
            
            _G.LeavesScanConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if not _G.LastLeavesScan or tick() - _G.LastLeavesScan > 2 then
                    _G.LastLeavesScan = tick()
                    
                    local character = game.Players.LocalPlayer.Character
                    if character and character:FindFirstChild("HumanoidRootPart") then
                        local position = character.HumanoidRootPart.Position
                        local range = 100 
                        
                        local parts = workspace:FindPartsInRegion3(
                            Region3.new(
                                position - Vector3.new(range, range, range),
                                position + Vector3.new(range, range, range)
                            ),
                            nil,
                            100
                        )
                        
                        for _, part in pairs(parts) do
                            pcall(function()
                                if part:IsA("MeshPart") and part:FindFirstChild("SurfaceAppearance") and not _G.OriginalLeavesTransparency[part] then
                                    processLeafObject(part)
                                end
                            end)
                        end
                    end
                end
            end)
        else
            if _G.OriginalLeavesTransparency then
                for obj, transparency in pairs(_G.OriginalLeavesTransparency) do
                    pcall(function()
                        if obj and obj:IsA("MeshPart") then
                            obj.Transparency = transparency
                        end
                    end)
                end
                
                _G.OriginalLeavesTransparency = nil
            end
            
            if _G.LeavesAddedConnection then
                _G.LeavesAddedConnection:Disconnect()
                _G.LeavesAddedConnection = nil
            end
            
            if _G.LeavesScanConnection then
                _G.LeavesScanConnection:Disconnect()
                _G.LeavesScanConnection = nil
            end
        end
    end
}, "HideLeaves")

sections.WorldVisual:Toggle({
    Name = "Hide Grass",
    Default = false,
    Callback = function(value)
        if Workspace and Workspace:FindFirstChild("Terrain") then
            sethiddenproperty(Workspace.Terrain, "Decoration", not value)
        end
    end
}, "DisableGrass")

sections.WorldVisual:Header({
    Text = "Fog Settings"
})


_G.FogSettings = {
    originalAtmosphereDensity = nil,
    originalFogEnd = nil,
    originalFogStart = nil,
    removeFogEnabled = false
}

sections.WorldVisual:Toggle({
    Name = "Remove Fog",
    Default = false,
    Callback = function(value)
        _G.FogSettings.removeFogEnabled = value
        
        if value then
            
            if Lighting:FindFirstChild("Atmosphere") and _G.FogSettings.originalAtmosphereDensity == nil then
                _G.FogSettings.originalAtmosphereDensity = Lighting.Atmosphere.Density
            end
            
            if _G.FogSettings.originalFogEnd == nil then
                _G.FogSettings.originalFogEnd = Lighting.FogEnd
            end
            
            if _G.FogSettings.originalFogStart == nil then
                _G.FogSettings.originalFogStart = Lighting.FogStart
            end
            
            
            if not _G.FogRemovalConnection then
                _G.FogRemovalConnection = RunService.Heartbeat:Connect(function()
                    if _G.FogSettings.removeFogEnabled then
                        if Lighting:FindFirstChild("Atmosphere") then
                            Lighting.Atmosphere.Density = 0
                        end
                        Lighting.FogEnd = 100000
                        Lighting.FogStart = 0
                    end
                end)
            end
        else
            
            if _G.FogRemovalConnection then
                _G.FogRemovalConnection:Disconnect()
                _G.FogRemovalConnection = nil
            end
            
            
            if Lighting:FindFirstChild("Atmosphere") and _G.FogSettings.originalAtmosphereDensity then
                Lighting.Atmosphere.Density = _G.FogSettings.originalAtmosphereDensity
            end
            
            if _G.FogSettings.originalFogEnd then
                Lighting.FogEnd = _G.FogSettings.originalFogEnd
            end
            
            if _G.FogSettings.originalFogStart then
                Lighting.FogStart = _G.FogSettings.originalFogStart
            end
        end
    end
}, "RemoveFog")

local function SafeCloudAccess()
    local terrain = workspace:FindFirstChildOfClass("Terrain")
    if not terrain then return nil end
    
    local clouds = nil
    local success = pcall(function() 
        clouds = terrain.Clouds 
    end)
    
    if not success or not clouds then return nil end
    
    return {
        getEnabled = function() 
            local enabled = false
            pcall(function() enabled = clouds.Enabled end)
            return enabled
        end,
        setEnabled = function(value) 
            pcall(function() clouds.Enabled = value end)
        end,
        getColor = function() 
            local color = Color3.fromRGB(255, 255, 255)
            pcall(function() color = clouds.Color end)
            return color
        end,
        setColor = function(value) 
            pcall(function() clouds.Color = value end)
        end,
        getCover = function() 
            local cover = 0.5
            pcall(function() cover = clouds.Cover end)
            return cover
        end,
        setCover = function(value) 
            pcall(function() clouds.Cover = value end)
        end,
        getDensity = function() 
            local density = 0.5
            pcall(function() density = clouds.Density end)
            return density
        end,
        setDensity = function(value) 
            pcall(function() clouds.Density = value end)
        end
    }
end

local cloudSection = tabs.World:Section({ Side = "Right", Name = "Cloud Settings" })

cloudSection:Header({
    Text = "Cloud Controls"
})

cloudSection:Toggle({
    Name = "Toggle Clouds",
    Default = true,
    Callback = function(value)
        if not _G.CloudSettings then
            _G.CloudSettings = {
                Enabled = true,
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.5,
                OriginalColor = nil,
                OriginalCover = nil,
                OriginalDensity = nil,
                OverrideActive = false
            }
        end
        
        _G.CloudSettings.Enabled = value
        
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end
        
        
        local cloudExists = false
        pcall(function() cloudExists = terrain.Clouds ~= nil end)
        
        if not cloudExists then
            warn("???????? Clouds ?? ?????????? ? ?????? ?????? Terrain. ??????? ??????? ??????????.")
            return
        end
        
        if not _G.CloudSettings.OriginalCover then
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                _G.CloudSettings.OriginalColor = cloudAccess.getColor()
                _G.CloudSettings.OriginalCover = cloudAccess.getCover()
                _G.CloudSettings.OriginalDensity = cloudAccess.getDensity()
            end
        end
        
        if _G.CloudsUpdateConnection then
            _G.CloudsUpdateConnection:Disconnect()
            _G.CloudsUpdateConnection = nil
        end
        
        if value then
            _G.CloudSettings.OverrideActive = true
            _G.CloudsUpdateConnection = RunService.Heartbeat:Connect(function()
                if _G.CloudSettings.OverrideActive then
                    
                    local cloudAccess = SafeCloudAccess()
                    if not cloudAccess then return end
                    
                    cloudAccess.setEnabled(true)
                    cloudAccess.setColor(_G.CloudSettings.Color)
                    cloudAccess.setCover(_G.CloudSettings.Cover)
                    cloudAccess.setDensity(_G.CloudSettings.Density)
                end
            end)
        else
            _G.CloudSettings.OverrideActive = false
            
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                cloudAccess.setEnabled(false)
            end
        end
    end
}, "ToggleClouds")

cloudSection:Colorpicker({
    Name = "Cloud Color",
    Default = Color3.fromRGB(255, 255, 255),
    Alpha = 0,
    Callback = function(color)
        if not _G.CloudSettings then
            _G.CloudSettings = {
                Enabled = true,
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.5,
                OriginalColor = nil,
                OriginalCover = nil,
                OriginalDensity = nil,
                OverrideActive = false
            }
        end
        
        _G.CloudSettings.Color = color
        
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end
        
        
        local cloudExists = false
        pcall(function() cloudExists = terrain.Clouds ~= nil end)
        
        if not cloudExists then
            warn("???????? Clouds ?? ?????????? ? ?????? ?????? Terrain. ??????? ??????? ??????????.")
            return
        end
        
        if not _G.CloudSettings.OriginalCover then
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                _G.CloudSettings.OriginalColor = cloudAccess.getColor()
                _G.CloudSettings.OriginalCover = cloudAccess.getCover()
                _G.CloudSettings.OriginalDensity = cloudAccess.getDensity()
            end
        end
        
        if _G.CloudSettings.OverrideActive then
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                cloudAccess.setColor(color)
            end
        end
    end
}, "CloudColor")

cloudSection:Slider({
    Name = "Cloud Cover",
    Default = 0.5,
    Minimum = 0,
    Maximum = 1,
    Precision = 2,
    Callback = function(value)
        if not _G.CloudSettings then
            _G.CloudSettings = {
                Enabled = true,
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.5,
                OriginalColor = nil,
                OriginalCover = nil,
                OriginalDensity = nil,
                OverrideActive = false
            }
        end
        
        _G.CloudSettings.Cover = value
        
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end
        
        
        local cloudExists = false
        pcall(function() cloudExists = terrain.Clouds ~= nil end)
        
        if not cloudExists then
            warn("???????? Clouds ?? ?????????? ? ?????? ?????? Terrain. ??????? ??????? ??????????.")
            return
        end
        
        if not _G.CloudSettings.OriginalCover then
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                _G.CloudSettings.OriginalColor = cloudAccess.getColor()
                _G.CloudSettings.OriginalCover = cloudAccess.getCover()
                _G.CloudSettings.OriginalDensity = cloudAccess.getDensity()
            end
        end
        
        if _G.CloudSettings.OverrideActive then
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                cloudAccess.setCover(value)
            end
        end
    end
}, "CloudCover")

cloudSection:Slider({
    Name = "Cloud Density",
    Default = 0.5,
    Minimum = 0,
    Maximum = 1,
    Precision = 2,
    Callback = function(value)
        if not _G.CloudSettings then
            _G.CloudSettings = {
                Enabled = true,
                Color = Color3.fromRGB(255, 255, 255),
                Cover = 0.5,
                Density = 0.5,
                OriginalColor = nil,
                OriginalCover = nil,
                OriginalDensity = nil,
                OverrideActive = false
            }
        end
        
        _G.CloudSettings.Density = value
        
        local terrain = Workspace:FindFirstChildOfClass("Terrain")
        if not terrain then return end
        
        
        local cloudExists = false
        pcall(function() cloudExists = terrain.Clouds ~= nil end)
        
        if not cloudExists then
            warn("???????? Clouds ?? ?????????? ? ?????? ?????? Terrain. ??????? ??????? ??????????.")
            return
        end
        
        if not _G.CloudSettings.OriginalCover then
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                _G.CloudSettings.OriginalColor = cloudAccess.getColor()
                _G.CloudSettings.OriginalCover = cloudAccess.getCover()
                _G.CloudSettings.OriginalDensity = cloudAccess.getDensity()
            end
        end
        
        if _G.CloudSettings.OverrideActive then
            local cloudAccess = SafeCloudAccess()
            if cloudAccess then
                cloudAccess.setDensity(value)
            end
        end
    end
}, "CloudDensity")

cloudSection:Button({
    Name = "Reset Cloud Settings",
    Callback = function()
        if _G.CloudSettings then

            _G.CloudSettings.OverrideActive = false
            
            if _G.CloudsUpdateConnection then
                _G.CloudsUpdateConnection:Disconnect()
                _G.CloudsUpdateConnection = nil
            end

            local terrain = Workspace:FindFirstChildOfClass("Terrain")
            if terrain and _G.CloudSettings.OriginalCover then
                
                local cloudExists = false
                pcall(function() cloudExists = terrain.Clouds ~= nil end)
                
                if not cloudExists then
                    warn("???????? Clouds ?? ?????????? ? ?????? ?????? Terrain. ??????? ??????? ??????????.")
                    return
                end

                local cloudAccess = SafeCloudAccess()
                if cloudAccess then
                    cloudAccess.setColor(_G.CloudSettings.OriginalColor)
                    cloudAccess.setCover(_G.CloudSettings.OriginalCover)
                    cloudAccess.setDensity(_G.CloudSettings.OriginalDensity)
                    cloudAccess.setEnabled(true)
                end
            end
            
            if _G.CloudSettings.OriginalCover then
                cloudSection:get_element("ToggleClouds"):set_value(true)
                cloudSection:get_element("CloudColor"):set_value(_G.CloudSettings.OriginalColor)
                cloudSection:get_element("CloudCover"):set_value(_G.CloudSettings.OriginalCover)
                cloudSection:get_element("CloudDensity"):set_value(_G.CloudSettings.OriginalDensity)
            end
            _G.CloudSettings = nil
        end
    end
})

local timeSection = tabs.World:Section({ Side = "Right", Name = "Time Settings" })

timeSection:Header({
    Text = "Time Changer"
})

timeSection:Toggle({
    Name = "Custom Time",
    Default = false,
    Callback = function(value)
        _G.TimeChangerEnabled = value
        
        if value then
            _G.OriginalTimeSettings = {
                ClockTime = Lighting.ClockTime,
                GeographicLatitude = Lighting.GeographicLatitude
            }
            
            
            if _G.ServerTimeUpdateConnection then
                _G.ServerTimeUpdateConnection:Disconnect()
                _G.ServerTimeUpdateConnection = nil
            end
            
            
            if not _G.TimeChangerConnection then
                _G.TimeChangerConnection = RunService.Heartbeat:Connect(function()
                    if _G.TimeChangerEnabled then
                        Lighting.ClockTime = _G.CustomTime or 12
                    end
                end)
            end
        else
            
            if _G.TimeChangerConnection then
                _G.TimeChangerConnection:Disconnect()
                _G.TimeChangerConnection = nil
            end
            
            
            if _G.OriginalTimeSettings then
                Lighting.ClockTime = _G.OriginalTimeSettings.ClockTime
                Lighting.GeographicLatitude = _G.OriginalTimeSettings.GeographicLatitude
                _G.OriginalTimeSettings = nil
            end
            
            
            _G.ServerTimeUpdateConnection = RunService.Heartbeat:Connect(function()
                task.wait(0.5)
                if _G.ServerTimeUpdateConnection then
                    _G.ServerTimeUpdateConnection:Disconnect()
                    _G.ServerTimeUpdateConnection = nil
                end
            end)
        end
    end
}, "CustomTime")

timeSection:Slider({
    Name = "Time of Day",
    Default = 12,
    Minimum = 0,
    Maximum = 24,
    Precision = 1,
    Callback = function(value)
        _G.CustomTime = value
        
        if _G.TimeChangerEnabled then
            Lighting.ClockTime = value
        end
    end
}, "TimeOfDay")

local Functions = {}

    function Functions:Create(Class, Properties)
        local _Instance = typeof(Class) == 'string' and Instance.new(Class) or Class
        for Property, Value in pairs(Properties) do
            _Instance[Property] = Value
        end
    return _Instance
    end
    
    function Functions:FadeOutOnDist(element, distance)
        local transparency = math.max(0.1, 1 - (distance / ESP.MaxDistance))
        if element:IsA("TextLabel") then
            element.TextTransparency = 1 - transparency
        elseif element:IsA("ImageLabel") then
            element.ImageTransparency = 1 - transparency
        elseif element:IsA("UIStroke") then
            element.Transparency = 1 - transparency
        elseif element:IsA("Frame") and (element.Name == "Healthbar" or element.Name == "BehindHealthbar") then
            element.BackgroundTransparency = 1 - transparency
        elseif element:IsA("Frame") then
            element.BackgroundTransparency = 1 - transparency
        elseif element:IsA("Highlight") then
            element.FillTransparency = 1 - transparency
            element.OutlineTransparency = 1 - transparency
    end
end

    function Functions:SilentAim()
        if Functions:TargetPlayer() and Configurations.Aimbot.Enabled then
            if Configurations.Aimbot['Aim Type'] == "Silent" and Configurations.Aimbot.Enabled and Functions:TargetPlayer() and SilentAim.Holding and tick() - autoshootdelay >= 0.30 then 
                local Origin = Camera.CFrame.p
                local Distination = Functions:TargetPlayer().Position
                local Velocity = Functions:TargetPlayer().Velocity
                local vm = game.FindFirstChildOfClass(Camera, "Model") or nil
                local aimpart = vm and game.FindFirstChild(vm, "AimPart") or nil

                autoshootdelay = tick()
                local rnd = math.random(-10000, 10000)
                
                
                ProjectileInflict:FireServer(
                    Functions:TargetPlayer(),
                    Functions:TargetPlayer().CFrame:ToObjectSpace(CFrame.new(Distination + Vector3.yAxis * 0.01)),
                    rnd,
                    0/0
                )
                
                
                FireProjectile:InvokeServer(
                    Vector3.new(0/0, 0/0, 0/0),
                    rnd,
                    autoshootdelay
                )
                
                local drawing, deleteme, deleteme1 = make_beam(aimpart and aimpart.Position or Camera.CFrame.p, Distination, Configurations.FOVSettings['FOV Circle'].Color)
                local wtf = -1
                local conn; conn = RunService.RenderStepped:Connect(LPH_JIT_MAX(function(delta)
                    wtf = wtf + delta
                    drawing.Transparency = NumberSequence.new(math.clamp(wtf, 0, 1))
                    if wtf >= 1 then
                        drawing:Destroy()
                        deleteme:Destroy()
                        deleteme1:Destroy()
                        conn:Disconnect()
                    end
                end))
            end
        end
    end

local function InitializeESP()
    local ScreenGui = Functions:Create("ScreenGui", {
        Parent = CoreGui,
        Name = "ESPHolder",
    })

    local function ESP_Draw(plr)
        local lplayer = Players.LocalPlayer
        local camera = Workspace.CurrentCamera
        local Cam = Workspace.CurrentCamera
        local RotationAngle, Tick = -45, tick()
        
        if ScreenGui:FindFirstChild(plr.Name) then
            ScreenGui[plr.Name]:Destroy()
        end
        
        local ESPContainer = Functions:Create("Folder", {
            Parent = ScreenGui,
            Name = plr.Name
        })
        
        local Name = Functions:Create("TextLabel", {
            Parent = ESPContainer,
            Position = UDim2.new(0.5, 0, 0, -11),
            Size = UDim2.new(0, 100, 0, 20),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            TextColor3 = ESP.Drawing.Names.RGB,
            Font = Enum.Font.Code,
            TextSize = ESP.FontSize,
            TextStrokeTransparency = 0,
            TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
            RichText = true
        })
        
        local Distance = Functions:Create("TextLabel", {
            Parent = ESPContainer,
            Position = UDim2.new(0.5, 0, 0, 11),
            Size = UDim2.new(0, 100, 0, 20),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            TextColor3 = ESP.Drawing.Distances.RGB,
            Font = Enum.Font.Code,
            TextSize = ESP.FontSize,
            TextStrokeTransparency = 0,
            TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
            RichText = true
        })
        
        local Box = Functions:Create("Frame", {
            Parent = ESPContainer,
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0.75,
            BorderSizePixel = 0,
            Name = "Box"
        })
        
        local Gradient1 = Functions:Create("UIGradient", {
            Parent = Box,
            Enabled = ESP.Drawing.Boxes.GradientFill,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientFillRGB1),
                ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientFillRGB2)
            }
        })
        
        local Outline = Functions:Create("UIStroke", {
            Parent = Box,
            Enabled = ESP.Drawing.Boxes.Gradient,
            Transparency = 0,
            Color = Color3.fromRGB(255, 255, 255),
            LineJoinMode = Enum.LineJoinMode.Miter
        })
        
        local Gradient2 = Functions:Create("UIGradient", {
            Parent = Outline,
            Enabled = ESP.Drawing.Boxes.Gradient,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientRGB1),
                ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientRGB2)
            }
        })
        
        local Healthbar = Functions:Create("Frame", {
            Parent = ESPContainer,
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 0,
            Name = "Healthbar"
        })
        
        local BehindHealthbar = Functions:Create("Frame", {
            Parent = ESPContainer,
            ZIndex = -1,
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 0,
            Name = "BehindHealthbar"
        })
        
        local HealthbarGradient = Functions:Create("UIGradient", {
            Parent = Healthbar,
            Enabled = ESP.Drawing.Healthbar.Gradient,
            Rotation = -90,
            Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, ESP.Drawing.Healthbar.GradientRGB1),
                ColorSequenceKeypoint.new(0.5, ESP.Drawing.Healthbar.GradientRGB2),
                ColorSequenceKeypoint.new(1, ESP.Drawing.Healthbar.GradientRGB3)
            }
        })
        
        local HealthText = Functions:Create("TextLabel", {
            Parent = ESPContainer,
            Position = UDim2.new(0.5, 0, 0, 31),
            Size = UDim2.new(0, 100, 0, 20),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            Font = Enum.Font.Code,
            TextSize = ESP.FontSize,
            TextStrokeTransparency = 0,
            TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        })
        
        local Chams = Functions:Create("Highlight", {
            Parent = ESPContainer,
            FillTransparency = 1,
            OutlineTransparency = 0,
            OutlineColor = Color3.fromRGB(119, 120, 255),
            DepthMode = "AlwaysOnTop"
        })
        
        local function HideESP()
            for _, child in pairs(ESPContainer:GetChildren()) do
                pcall(function()
                    if child:IsA("GuiObject") then
                        child.Visible = false
                    elseif child:IsA("Highlight") then
                        child.Enabled = false
                    end
                end)
            end
            
            Box.Visible = false
            Name.Visible = false
            Distance.Visible = false
            Healthbar.Visible = false
            BehindHealthbar.Visible = false
            HealthText.Visible = false
            Chams.Enabled = false
            
            if not plr or not plr.Parent then
                ESPContainer:Destroy()
                return
            end
        end
        
        local Connection = RunService.RenderStepped:Connect(function()
            if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") and ESP.Enabled then
                local HRP = plr.Character.HumanoidRootPart
                local Humanoid = plr.Character:FindFirstChild("Humanoid")
                
                if not Humanoid then return end
                
                local Pos, OnScreen = Cam:WorldToScreenPoint(HRP.Position)
                local Dist = (Cam.CFrame.Position - HRP.Position).Magnitude / 3.5714285714
                
                if OnScreen and Dist <= ESP.MaxDistance then
                    local Size = HRP.Size.Y
                    
                    local realDist = (Cam.CFrame.Position - HRP.Position).Magnitude
                    local baseFOV = 70 
                    local fovCompensation = math.tan(math.rad(baseFOV) / 2) / math.tan(math.rad(Cam.FieldOfView) / 2)
                    local fixedScaleFactor = (Size * Cam.ViewportSize.Y) / (realDist * 2) * fovCompensation
                    local w, h = 3 * fixedScaleFactor, 4.5 * fixedScaleFactor
                    
                    if ESP.FadeOut.OnDistance then
                        Functions:FadeOutOnDist(Box, Dist)
                        Functions:FadeOutOnDist(Outline, Dist)
                        Functions:FadeOutOnDist(Name, Dist)
                        Functions:FadeOutOnDist(Distance, Dist)
                        Functions:FadeOutOnDist(Healthbar, Dist)
                        Functions:FadeOutOnDist(BehindHealthbar, Dist)
                        Functions:FadeOutOnDist(HealthText, Dist)
                        Functions:FadeOutOnDist(Chams, Dist)
                    end
                    
                    if not ESP.TeamCheck or plr == lplayer or ((lplayer.Team ~= plr.Team and plr.Team) or (not lplayer.Team and not plr.Team)) then
                        if ESP.Drawing.Chams.Enabled then
                            Chams.Adornee = plr.Character
                            Chams.Enabled = true
                            Chams.FillColor = ESP.Drawing.Chams.FillRGB
                            Chams.OutlineColor = ESP.Drawing.Chams.OutlineRGB
                            
                            if ESP.Drawing.Chams.Thermal then
                                local breathe_effect = math.atan(math.sin(tick() * 2)) * 2 / math.pi
                                Chams.FillTransparency = ESP.Drawing.Chams.Fill_Transparency * breathe_effect * 0.01
                                Chams.OutlineTransparency = ESP.Drawing.Chams.Outline_Transparency * breathe_effect * 0.01
                            end
                            
                            if ESP.Drawing.Chams.XRay then
                                Chams.DepthMode = "AlwaysOnTop"
                            else
                                Chams.DepthMode = ESP.Drawing.Chams.VisibleCheck and "Occluded" or "AlwaysOnTop"
                            end
                        else
                            Chams.Enabled = false
                        end
                        
                        Box.Position = UDim2.new(0, Pos.X - w / 2, 0, Pos.Y - h / 2)
                        Box.Size = UDim2.new(0, w, 0, h)
                        Box.Visible = ESP.Drawing.Boxes.Full.Enabled
                        
                        Gradient1.Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientFillRGB1),
                            ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientFillRGB2)
                        }
                        
                        Gradient2.Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientRGB1),
                            ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientRGB2)
                        }

                        if ESP.Drawing.Boxes.Filled.Enabled then
                            Box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                            
                            if ESP.Drawing.Boxes.GradientFill then
                                Box.BackgroundTransparency = ESP.Drawing.Boxes.Filled.Transparency
                            else
                                Box.BackgroundTransparency = 1
                            end
                            Box.BorderSizePixel = 1
                        else
                            Box.BackgroundTransparency = 1
                        end
                        
                        RotationAngle = RotationAngle + (tick() - Tick) * ESP.Drawing.Boxes.RotationSpeed * math.cos(math.pi / 4 * tick() - math.pi / 2)
                        if ESP.Drawing.Boxes.Animate then
                            Gradient1.Rotation = RotationAngle
                            Gradient2.Rotation = RotationAngle
                        else
                            Gradient1.Rotation = -45
                            Gradient2.Rotation = -45
                        end
                        Tick = tick()
                        
                        local health = Humanoid.Health / Humanoid.MaxHealth
                        Healthbar.Visible = ESP.Drawing.Healthbar.Enabled
                        
                        Healthbar.Position = UDim2.new(0, Pos.X - w / 2 - 6, 0, Pos.Y - h / 2 + h * (1 - health))
                        Healthbar.Size = UDim2.new(0, ESP.Drawing.Healthbar.Width, 0, h * health)
                        
                        BehindHealthbar.Visible = ESP.Drawing.Healthbar.Enabled
                        BehindHealthbar.Position = UDim2.new(0, Pos.X - w / 2 - 6, 0, Pos.Y - h / 2)
                        BehindHealthbar.Size = UDim2.new(0, ESP.Drawing.Healthbar.Width, 0, h)
                        
                        HealthbarGradient.Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0, ESP.Drawing.Healthbar.GradientRGB1),
                            ColorSequenceKeypoint.new(0.5, ESP.Drawing.Healthbar.GradientRGB2),
                            ColorSequenceKeypoint.new(1, ESP.Drawing.Healthbar.GradientRGB3)
                        }
                        
                        if ESP.Drawing.Healthbar.HealthText then
                            local healthPercentage = math.floor(Humanoid.Health / Humanoid.MaxHealth * 100)
                            HealthText.Position = UDim2.new(0, Pos.X - w / 2 - 6, 0, Pos.Y - h / 2 + h * (1 - healthPercentage / 100) + 3)
                            HealthText.Text = tostring(healthPercentage)
                            HealthText.Visible = Humanoid.Health < Humanoid.MaxHealth
                            if ESP.Drawing.Healthbar.Lerp then
                                local color = health >= 0.75 and Color3.fromRGB(0, 255, 0) or health >= 0.5 and Color3.fromRGB(255, 255, 0) or health >= 0.25 and Color3.fromRGB(255, 170, 0) or Color3.fromRGB(255, 0, 0)
                                HealthText.TextColor3 = color
                            else
                                HealthText.TextColor3 = ESP.Drawing.Healthbar.HealthTextRGB
                            end
                        end
                        
                        Name.Visible = ESP.Drawing.Names.Enabled
                        Name.TextColor3 = ESP.Drawing.Names.RGB
                        if ESP.Options.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                            Name.Text = string.format('(<font color="rgb(%d, %d, %d)">F</font>) %s', 
                                ESP.Options.FriendcheckRGB.R * 255, 
                                ESP.Options.FriendcheckRGB.G * 255, 
                                ESP.Options.FriendcheckRGB.B * 255, 
                                plr.Name)
                        else
                            if Players:GetPlayerFromCharacter(plr.Character) == nil and ESP.ShowAIBots then
                                Name.Text = string.format('(<font color="rgb(%d, %d, %d)">AI</font>) %s', 255, 0, 0, plr.Name)
                            else
                                Name.Text = string.format('(<font color="rgb(%d, %d, %d)">E</font>) %s', 255, 0, 0, plr.Name)
                            end
                        end
                        Name.Position = UDim2.new(0, Pos.X, 0, Pos.Y - h / 2 - 9)
                        
                        if ESP.Drawing.Distances.Enabled then
                            Distance.TextColor3 = ESP.Drawing.Distances.RGB
                            if ESP.Drawing.Distances.Position == "Bottom" then
                                Distance.Position = UDim2.new(0, Pos.X, 0, Pos.Y + h / 2 + 7)
                                Distance.Text = string.format("%d meters", math.floor(Dist))
                                Distance.Visible = true
                            elseif ESP.Drawing.Distances.Position == "Text" then
                                Distance.Visible = false
                                if ESP.Options.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                                    Name.Text = string.format('(<font color="rgb(%d, %d, %d)">F</font>) %s [%d]', 
                                        ESP.Options.FriendcheckRGB.R * 255, 
                                        ESP.Options.FriendcheckRGB.G * 255, 
                                        ESP.Options.FriendcheckRGB.B * 255, 
                                        plr.Name, 
                                        math.floor(Dist))
                                else
                                    if Players:GetPlayerFromCharacter(plr.Character) == nil and ESP.ShowAIBots then
                                        Name.Text = string.format('(<font color="rgb(%d, %d, %d)">AI</font>) %s [%d]', 255, 0, 0, plr.Name, math.floor(Dist))
                                    else
                                        Name.Text = string.format('(<font color="rgb(%d, %d, %d)">E</font>) %s [%d]', 255, 0, 0, plr.Name, math.floor(Dist))
                                    end
                                end
                                Name.Visible = ESP.Drawing.Names.Enabled
                            end
                        end
                    else
                        HideESP()
                    end
                else
                    HideESP()
                end
            else
                HideESP()
            end
        end)
        
        plr.AncestryChanged:Connect(function()
            if not plr:IsDescendantOf(game) then
                Connection:Disconnect()
                ESPContainer:Destroy()
            end
        end)
    end
    
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= Players.LocalPlayer then
            task.spawn(ESP_Draw, player)
        end
    end
    
    Players.PlayerAdded:Connect(function(player)
        if player ~= Players.LocalPlayer then
            task.spawn(ESP_Draw, player)
        end
    end)
end

    RunService.RenderStepped:Connect(function()
    if ESP.Enabled and not ESP.Initialized then
        pcall(function()
            local oldGui = CoreGui:FindFirstChild("ESPHolder")
            if oldGui then
                oldGui:Destroy()
            end
        end)
        
        ESP.Initialized = true
        InitializeESP()
    end
    
    if ESP.Enabled and ESP.Initialized then
        local espHolder = CoreGui:FindFirstChild("ESPHolder")
        if not espHolder or #espHolder:GetChildren() == 0 then
            ESP.Initialized = false 
        end
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.End then
        ESP.Enabled = not ESP.Enabled
        
        if ESP.Enabled then
            ForceESPRefresh()
        end
        
        pcall(function()
            local espToggle = sections.ESPMain:get_element("EnableESP")
            if espToggle then
                espToggle:set_value({Toggle = ESP.Enabled})
            end
        end)
    end
end)

MacLib:SetFolder("leadmarker")
tabs.Settings:InsertConfigSection("Left")
tabs.Aimbot:Select()
MacLib:LoadAutoLoadConfig()

local function CreateCustomWatermark()

    if _G.CustomWatermark then return end
    
    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")

    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "OblivionWatermark"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    if syn and syn.protect_gui then
        syn.protect_gui(screenGui)
        screenGui.Parent = game:GetService("CoreGui")
    else
        screenGui.Parent = playerGui
    end

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "WatermarkFrame"
    mainFrame.Position = UDim2.new(0, 15, 0, 60)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20) 
    mainFrame.BorderSizePixel = 0
    mainFrame.AutomaticSize = Enum.AutomaticSize.X
    mainFrame.Size = UDim2.new(0, 0, 0, 30) 
    mainFrame.Parent = screenGui
    
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 5) 
    uiCorner.Parent = mainFrame

    local padding = Instance.new("UIPadding")
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingRight = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 5)
    padding.PaddingBottom = UDim.new(0, 5)
    padding.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1 
    stroke.Color = Color3.fromRGB(60, 60, 60) 
    stroke.Parent = mainFrame

    local accentBar = Instance.new("Frame")
    accentBar.Name = "AccentBar"
    accentBar.Position = UDim2.new(0, 0, 0, 0)
    accentBar.Size = UDim2.new(1, 0, 0, 1)
    accentBar.BorderSizePixel = 0
    accentBar.BackgroundColor3 = Color3.fromRGB(113, 93, 255)
    accentBar.Parent = mainFrame

    local accentGradient = Instance.new("UIGradient")
    accentGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 102, 102)), 
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(113, 93, 255)), 
        ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 214, 160)) 
    }
    accentGradient.Parent = accentBar

    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = mainFrame
    textLabel.Size = UDim2.new(0, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.TextColor3 = Color3.new(1, 1, 1) 
    textLabel.Font = Enum.Font.Gotham 
    textLabel.TextSize = 13 
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.AutomaticSize = Enum.AutomaticSize.X

    local lastFrameTime = tick()
    local fps = 60

    local gradientOffset = 0
    RunService.RenderStepped:Connect(function()
        local now = tick()
        local delta = now - lastFrameTime
        lastFrameTime = now
        fps = math.floor(1 / delta)

        gradientOffset = (gradientOffset + delta * 0.1) % 1
        accentGradient.Offset = Vector2.new(gradientOffset, 0)
    end)

    local function updateText()
        local timeStr = os.date("%H:%M:%S")
        local dateStr = os.date("%d/%m/%Y")
        textLabel.Text = string.format("Oblivion | %s | %s | %d FPS", timeStr, dateStr, fps)
    end

    local updateConnection
    updateConnection = RunService.Heartbeat:Connect(function()
        if screenGui.Enabled then
            updateText()
        end
    end)

    _G.CustomWatermark = screenGui

    screenGui.Enabled = true

    return screenGui
end

task.spawn(CreateCustomWatermark)

local function safeESPOptions()

    if not ESP.Options then
        ESP.Options = {
            Teamcheck = false,
            TeamcheckRGB = Color3.fromRGB(0, 255, 0),
            Friendcheck = false,
            FriendcheckRGB = Color3.fromRGB(0, 255, 0),
            Highlight = false,
            HighlightRGB = Color3.fromRGB(255, 0, 0)
        }
    end
    
    if ESP.Options.Friendcheck == nil then
        ESP.Options.Friendcheck = false
    end
    
    if ESP.Options.FriendcheckRGB == nil then
        ESP.Options.FriendcheckRGB = Color3.fromRGB(0, 255, 0)
    end
    
    if ESP.Options.Teamcheck == nil then
        ESP.Options.Teamcheck = false
    end
    
    if ESP.Options.TeamcheckRGB == nil then
        ESP.Options.TeamcheckRGB = Color3.fromRGB(0, 255, 0)
    end
    
    if ESP.Options.Highlight == nil then
        ESP.Options.Highlight = false
    end
    
    if ESP.Options.HighlightRGB == nil then
        ESP.Options.HighlightRGB = Color3.fromRGB(255, 0, 0)
    end
end

safeESPOptions()

local function UpdateESPSettings()
    if ESP.Enabled then
        for _, player in pairs(game:GetService("Players"):GetPlayers()) do
            if player ~= game:GetService("Players").LocalPlayer then
                local espHolder = game:GetService("CoreGui"):FindFirstChild("ESPHolder")
                if espHolder and espHolder:FindFirstChild(player.Name) then
                    local playerESP = espHolder:FindFirstChild(player.Name)

                    local nameLabel = playerESP:FindFirstChildOfClass("TextLabel")
                    if nameLabel then
                        nameLabel.Visible = ESP.Drawing.Names.Enabled
                    end

                    local distanceLabels = {}
                    for _, child in pairs(playerESP:GetChildren()) do
                        if child:IsA("TextLabel") and child ~= nameLabel then
                            table.insert(distanceLabels, child)
                        end
                    end
                    for _, label in pairs(distanceLabels) do
                        label.Visible = ESP.Drawing.Distances.Enabled
                    end
                end
            end
        end
    end
end

local originalUpdateESP = UpdateESPSettings
UpdateESPSettings = function()
    if originalUpdateESP then
        originalUpdateESP()
    end

    pcall(function()
        local espHolder = game:GetService("CoreGui"):FindFirstChild("ESPHolder")
        if espHolder and ESP.Enabled then
            for _, playerESP in pairs(espHolder:GetChildren()) do
                if not playerESP:IsA("Frame") then continue end
                
                for _, child in pairs(playerESP:GetChildren()) do
                    if child:IsA("TextLabel") then
                        if (child.Text:find("meters") or child.Position.Y.Offset > 0) and
                           ESP.Drawing.Distances.RGB then
                            child.TextColor3 = ESP.Drawing.Distances.RGB
                        end

                        if not child.Text:find("rgb") and
                           (child.Position.Y.Offset < 0 or child.Text:find("E") or child.Text:find("F")) and
                           ESP.Drawing.Names.RGB then
                            child.TextColor3 = ESP.Drawing.Names.RGB
                        end
                    end
                end
            end
        end
    end)
end


UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    
    if input.KeyCode == Enum.KeyCode.F3 and WorldESP.Enabled then
        
        
        
        local toRemove = {}
        for instance, data in pairs(WorldESP.TrackedItems) do
            if data.IsContainer then
                if data.Drawing then
                    returnDrawingToPool(data.Drawing)
                    data.Drawing = nil
                end
                table.insert(toRemove, instance)
            end
        end
        
        for _, instance in ipairs(toRemove) do
            WorldESP.TrackedItems[instance] = nil
        end
        
        
        local containers = Workspace:FindFirstChild("Containers")
        if containers then
            local count = 0
            
            
            local function scanRecursive(parent)
                for _, child in pairs(parent:GetChildren()) do
                    if count >= 300 then return end 
                    
                    pcall(function()
                        
                        if child:IsA("MeshPart") then
                            local container = child.Parent
                            if container and not WorldESP.TrackedItems[container] then
                                trackItem(container, "????: " .. container.Name, false, true, false)
                                count = count + 1
                            end
                        end
                        
                        
                        if child:IsA("Model") and not WorldESP.TrackedItems[child] then
                            local hasMeshPart = false
                            for _, subchild in pairs(child:GetDescendants()) do
                                if subchild:IsA("MeshPart") then
                                    hasMeshPart = true
                                    break
                                end
                            end
                            
                            if hasMeshPart then
                                trackItem(child, "????: " .. child.Name, false, true, false)
                                count = count + 1
                            end
                        end
                        
                        
                        if #child:GetChildren() > 0 then
                            scanRecursive(child)
                        end
                    end)
                end
            end
            
            scanRecursive(containers)
            
        end
    end
end)

local ZoomSection = tabs.Player:Section({ Side = "Left", Name = "Zoom Settings" })

ZoomSection:Header({
    Text = "Zoom Settings"
})

local function createZoom(time, amount, isZoomIn)
    if ZoomSettings.CurrentTween then
        ZoomSettings.CurrentTween:Cancel()
        ZoomSettings.CurrentTween = nil
    end
    
    local Tween_Info = TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut) 
    local Tween = game:GetService("TweenService"):Create(Workspace.CurrentCamera, Tween_Info, {FieldOfView = amount})
    
    Tween.Completed:Connect(function()
        ZoomSettings.CurrentTween = nil
        
        
        if not isZoomIn then
            ZoomSettings.IsZooming = false
            
            
            if ZoomSettings.IsFOVChangerActive and FOVChangerSettings and FOVChangerSettings.Enabled then
                
                task.delay(0.05, function()
                    if not ZoomSettings.IsZooming then
                        Workspace.CurrentCamera.FieldOfView = FOVChangerSettings.CustomFOV
                    end
                end)
            else
                
                task.delay(0.05, function()
                    if not ZoomSettings.IsZooming and Workspace.CurrentCamera.FieldOfView ~= ZoomSettings.OldZoom then
                        Workspace.CurrentCamera.FieldOfView = ZoomSettings.OldZoom
                    end
                end)
            end
        end
    end)
    
    ZoomSettings.CurrentTween = Tween
    return Tween
end


local function resetZoom()
    if not ZoomSettings.IsKeyDown and ZoomSettings.IsZooming then
        
        ZoomSettings.IsZooming = false
        
        if ZoomSettings.CurrentTween then
            ZoomSettings.CurrentTween:Cancel()
            ZoomSettings.CurrentTween = nil
        end
        
        
        if ZoomSettings.IsFOVChangerActive and FOVChangerSettings and FOVChangerSettings.Enabled then
            Workspace.CurrentCamera.FieldOfView = FOVChangerSettings.CustomFOV
        else
            Workspace.CurrentCamera.FieldOfView = ZoomSettings.OldZoom
        end
    end
end


local function setupZoomBindings()
    
    if ZoomSettings.InputConnection then
        ZoomSettings.InputConnection:Disconnect()
        ZoomSettings.InputConnection = nil
    end
    
    if ZoomSettings.EndConnection then
        ZoomSettings.EndConnection:Disconnect()
        ZoomSettings.EndConnection = nil
    end
    
    
    ZoomSettings.IsZooming = false
    ZoomSettings.IsKeyDown = false
    
    
    if not ZoomSettings.Enabled then
        resetZoom()
        return
    end
    
    
    ZoomSettings.InputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode ~= ZoomSettings.Key then return end
        
        
        ZoomSettings.IsKeyDown = true
        
        
        ZoomSettings.IsFOVChangerActive = FOVChangerSettings and FOVChangerSettings.Enabled
        
        
        if not ZoomSettings.IsZooming then
            
            if ZoomSettings.IsFOVChangerActive then
                
                ZoomSettings.OldZoom = FOVChangerSettings.CustomFOV
            else
                
                ZoomSettings.OldZoom = Workspace.CurrentCamera.FieldOfView
            end
        end
        
        
        ZoomSettings.IsZooming = true
        createZoom(ZoomSettings.ZoomTime, ZoomSettings.ZoomedAmount, true):Play()
    end)
    
    
    ZoomSettings.EndConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if input.KeyCode ~= ZoomSettings.Key then return end
        
        
        ZoomSettings.IsKeyDown = false
        
        
        if not ZoomSettings.IsZooming then return end
        
        
        if ZoomSettings.IsFOVChangerActive and FOVChangerSettings and FOVChangerSettings.Enabled then
            createZoom(ZoomSettings.ZoomTime, FOVChangerSettings.CustomFOV, false):Play()
        else
            createZoom(ZoomSettings.ZoomTime, ZoomSettings.OldZoom, false):Play()
        end
    end)
end


ZoomSection:Toggle({
    Name = "Enable Zoom",
    Default = false,
    Callback = function(value)
        ZoomSettings.Enabled = value
        setupZoomBindings()
    end
})


ZoomSection:Slider({
    Name = "Zoom Amount",
    Default = 10,
    Minimum = 5,
    Maximum = 40,
    Precision = 2,
    Callback = function(value)
        ZoomSettings.ZoomedAmount = value
    end
})


ZoomSection:Keybind({
    Name = "Zoom Key",
    Default = Enum.KeyCode.C,
    Callback = function() end,
    KeyChanged = function(key)
        ZoomSettings.Key = key
        setupZoomBindings()
    end
})


setupZoomBindings()


local lastKeyCheck = tick()
RunService.Heartbeat:Connect(function()
    
    if tick() - lastKeyCheck > 1 then
        lastKeyCheck = tick()
        resetZoom()  
    end
end)


local FOVChangerSection = tabs.Player:Section({ Side = "Left", Name = "FOV Changer" })

FOVChangerSection:Header({
    Text = "FOV Changer"
})

local FOVChangerSettings = {
    Enabled = false,
    CustomFOV = 90,
    DefaultFOV = workspace.CurrentCamera.FieldOfView,
    UpdateConnection = nil,
    CurrentTween = nil
}

local function updateFOV(instant)
    if not FOVChangerSettings.Enabled then
        if workspace.CurrentCamera.FieldOfView ~= FOVChangerSettings.DefaultFOV then
            if instant then
                workspace.CurrentCamera.FieldOfView = FOVChangerSettings.DefaultFOV
            else
                if FOVChangerSettings.CurrentTween then
                    FOVChangerSettings.CurrentTween:Cancel()
                end
                
                FOVChangerSettings.CurrentTween = game:GetService("TweenService"):Create(
                    workspace.CurrentCamera,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    {FieldOfView = FOVChangerSettings.DefaultFOV}
                )
                FOVChangerSettings.CurrentTween:Play()
            end
        end
    else
        if workspace.CurrentCamera.FieldOfView ~= FOVChangerSettings.CustomFOV then
            if instant then
                workspace.CurrentCamera.FieldOfView = FOVChangerSettings.CustomFOV
            else
                if FOVChangerSettings.CurrentTween then
                    FOVChangerSettings.CurrentTween:Cancel()
                end
                
                FOVChangerSettings.CurrentTween = game:GetService("TweenService"):Create(
                    workspace.CurrentCamera,
                    TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
                    {FieldOfView = FOVChangerSettings.CustomFOV}
                )
                FOVChangerSettings.CurrentTween:Play()
            end
        end
    end
end

local function setupFOVChanger()
    if FOVChangerSettings.UpdateConnection then
        FOVChangerSettings.UpdateConnection:Disconnect()
    end
    
    FOVChangerSettings.UpdateConnection = workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
        if ZoomSettings.IsZooming then return end
        
        if FOVChangerSettings.Enabled and workspace.CurrentCamera.FieldOfView ~= FOVChangerSettings.CustomFOV then
            if not FOVChangerSettings.CurrentTween or FOVChangerSettings.CurrentTween.PlaybackState == Enum.PlaybackState.Completed then
                workspace.CurrentCamera.FieldOfView = FOVChangerSettings.CustomFOV
            end
        end
    end)
end

FOVChangerSection:Toggle({
    Name = "Enable FOV Changer",
    Default = false,
    Callback = function(value)
        FOVChangerSettings.Enabled = value
        
        
        ZoomSettings.IsFOVChangerActive = value
        
        
        if not ZoomSettings.IsZooming then
            updateFOV()
        end
        
        
        if value and not FOVChangerSettings.UpdateConnection then
            FOVChangerSettings.UpdateConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
                
                if ZoomSettings.IsZooming then return end
                
                if FOVChangerSettings.Enabled and Workspace.CurrentCamera.FieldOfView ~= FOVChangerSettings.CustomFOV then
                    
                    
                    if not FOVChangerSettings.CurrentTween or FOVChangerSettings.CurrentTween.PlaybackState == Enum.PlaybackState.Completed then
                        Workspace.CurrentCamera.FieldOfView = FOVChangerSettings.CustomFOV
                    end
                end
            end)
        elseif not value and FOVChangerSettings.UpdateConnection then
            FOVChangerSettings.UpdateConnection:Disconnect()
            FOVChangerSettings.UpdateConnection = nil
        end
    end
})


FOVChangerSection:Slider({
    Name = "Custom FOV",
    Default = 90,
    Minimum = 30,
    Maximum = 120,
    Precision = 2,
    Callback = function(value)
        FOVChangerSettings.CustomFOV = value
        if FOVChangerSettings.Enabled and not ZoomSettings.IsZooming then
            updateFOV()
        end
    end
})




FOVChangerSettings.DefaultFOV = Workspace.CurrentCamera.FieldOfView


local ArmsVisual = {
    Enabled = false,
    Color = Color3.fromRGB(0, 255, 255),
    Transparency = 0.5,
    Material = Enum.Material.ForceField,
    SavedAppearances = {},
    CachedViewModel = nil,
    LastViewModelCheck = nil,
    LastUsedColor = nil,
    LastUsedTransparency = nil,
    LastUsedMaterial = nil,
    LastUpdateTime = nil,
    
    IgnoreList = {
        ["camera"] = true,
        ["Camera"] = true,
        ["CAMERA"] = true,
        ["camerapart"] = true,
        ["CameraPart"] = true,
        ["camerascript"] = true,
        ["CameraScript"] = true,
        ["cameramodule"] = true,
        ["CameraModule"] = true,
        ["cameracontroller"] = true,
        ["CameraController"] = true
    },
    
    StrictPathProcessing = true,
    
    AllowedPaths = {
        "ViewModel",
        "Arms",
        "Weapon",
        "Gun",
        "Knife",
        "Hands",
        "Tool"
    }
}

local function UpdateArmsVisual(color, transparency)
    if not color or transparency == nil then return end 
    
    local function shouldIgnore(obj)
        if not obj then return true end
        
        local current = obj
        while current and current ~= workspace.Camera do
            local name = current.Name:lower()
            if ArmsVisual.IgnoreList[name] then
                return true
            end
            
            if name:find("camera") then
                return true
            end
            
            current = current.Parent
        end
        
        if ArmsVisual.StrictPathProcessing then
            local isAllowed = false
            local current = obj
            while current and current ~= workspace.Camera do
                local name = current.Name:lower()
                for _, allowedPath in ipairs(ArmsVisual.AllowedPaths) do
                    if name:find(allowedPath:lower()) then
                        isAllowed = true
                        break
                    end
                end
                if isAllowed then break end
                current = current.Parent
            end
            return not isAllowed
        end
        
        return false
    end
    
    local viewModel = ArmsVisual.CachedViewModel
    local currentTime = tick()
    
    local forceUpdate = not viewModel or not viewModel.Parent
    if forceUpdate or not ArmsVisual.LastViewModelCheck or (currentTime - ArmsVisual.LastViewModelCheck) > 0.5 then
        viewModel = nil
        
        local validViewModels = {}
        
        pcall(function()
            for _, child in ipairs(workspace.Camera:GetChildren()) do
                if child and child:IsA("Model") and not shouldIgnore(child) then
                    table.insert(validViewModels, child)
                end
            end
        end)
        
        if #validViewModels > 0 then
            viewModel = validViewModels[1]
        end
        
        if viewModel then
            ArmsVisual.CachedViewModel = viewModel
            ArmsVisual.LastViewModelCheck = currentTime
        end
    end
    
    if not viewModel then return end
    
    local function safeSetTransparency(object, value)
        pcall(function()
            if not object or typeof(object) ~= "Instance" or shouldIgnore(object) then return end
            
            if object:IsA("ParticleEmitter") or object:IsA("Beam") or object:IsA("Trail") then
                if typeof(value) == "number" then
                    object.Transparency = NumberSequence.new(value)
                end
            elseif typeof(value) == "number" then
                object.Transparency = value
            end
        end)
    end
    
    local function safeSet(obj, prop, value)
        if not obj or typeof(obj) ~= "Instance" or shouldIgnore(obj) then return end
        pcall(function() obj[prop] = value end)
    end
    
    local timeThreshold = 0.25
    local skipCacheUpdate = false
    
    if ArmsVisual.LastUpdateTime and (currentTime - ArmsVisual.LastUpdateTime) < timeThreshold then
        if ArmsVisual.LastUsedColor and ArmsVisual.LastUsedTransparency and
           ArmsVisual.LastUsedMaterial and ArmsVisual.Enabled and
           ArmsVisual.LastUsedColor == color and
           math.abs(ArmsVisual.LastUsedTransparency - transparency) < 0.01 and
           ArmsVisual.LastUsedMaterial == ArmsVisual.Material then
            skipCacheUpdate = true
        end
    end
    
    if not skipCacheUpdate then
        ArmsVisual.LastUsedColor = color
        ArmsVisual.LastUsedTransparency = transparency
        ArmsVisual.LastUsedMaterial = ArmsVisual.Material
        ArmsVisual.LastUpdateTime = currentTime
        
        local partsToProcess = {}
        for _, part in ipairs(viewModel:GetDescendants()) do
            if shouldIgnore(part) then
                continue
            end
            
            local className = part.ClassName
            local validPartTypes = {
                ["BasePart"] = true,
                ["MeshPart"] = true,
                ["Part"] = true,
                ["UnionOperation"] = true
            }
            
            if validPartTypes[className] then
                if part.Transparency < 1 then
                    table.insert(partsToProcess, part)
                    safeSet(part, "CanCollide", false)
                end
            elseif part:IsA("Decal") or part:IsA("Texture") then
                if ArmsVisual.Enabled then
                    safeSetTransparency(part, 1)
                else
                    safeSetTransparency(part, 0)
                end
            elseif part:IsA("ParticleEmitter") or part:IsA("Beam") or part:IsA("Trail") then
                if ArmsVisual.Enabled then
                    safeSet(part, "Enabled", false)
                    safeSetTransparency(part, 1)
                else
                    safeSet(part, "Enabled", true)
                    safeSetTransparency(part, 0)
                end
            end
        end
        
        for _, part in ipairs(partsToProcess) do
            pcall(function()
                if ArmsVisual.Enabled then
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("SurfaceAppearance") and not ArmsVisual.SavedAppearances[child] then
                            ArmsVisual.SavedAppearances[child] = part
                            child.Parent = nil
                        end
                    end
                    
                    for _, child in ipairs(part:GetChildren()) do
                        if child:IsA("SpecialMesh") or child:IsA("BlockMesh") or child:IsA("CylinderMesh") then
                            safeSet(child, "TextureId", "")
                            pcall(function() 
                                child.VertexColor = Vector3.new(color.R, color.G, color.B) 
                            end)
                        end
                    end
                    
                    safeSet(part, "TextureID", "")
                    safeSet(part, "Material", ArmsVisual.Material)
                    safeSet(part, "Reflectance", 0)
                    safeSet(part, "Color", color)
                    
                    if transparency >= 0 then
                        safeSet(part, "Transparency", transparency)
                    end
                else
                    for stored, parent in pairs(ArmsVisual.SavedAppearances) do
                        if parent == part then
                            stored.Parent = parent
                        end
                    end
                    
                    safeSet(part, "Material", Enum.Material.SmoothPlastic)
                    safeSet(part, "Transparency", 0)
                end
            end)
        end
    end
    
    if not ArmsVisual.Enabled then
        ArmsVisual.SavedAppearances = {}
        ArmsVisual.LastUsedColor = nil
        ArmsVisual.LastUsedTransparency = nil
        ArmsVisual.LastUsedMaterial = nil
    end
    
    if ArmsVisual.LastUsedTransparency ~= transparency then
        ArmsVisual.LastUsedTransparency = transparency
        ArmsVisual.LastUpdateTime = tick() - 1 
    end
end

local function SetupWeaponChangeListener()
    local camera = workspace.Camera
    
    if ArmsVisual.WeaponChangeConnection then
        ArmsVisual.WeaponChangeConnection:Disconnect()
        ArmsVisual.WeaponChangeConnection = nil
    end
    
    local function shouldProcess(obj)
        if not obj or not obj:IsA("Model") then 
            return false 
        end
        
        local name = obj.Name:lower()
        if (ArmsVisual.IgnoreList and ArmsVisual.IgnoreList[name]) or name:find("camera") then
            return false
        end
        
        local isViewModel = name:find("view") or name:find("arm") or 
                           name:find("weapon") or name:find("hand") or
                           name:find("gun") or name:find("item") or name:find("model") 
        return isViewModel
    end
    
    local function updateViewModel(model)
        if not model or not ArmsVisual.Enabled then return end
        
        ArmsVisual.LastUsedColor = nil
        ArmsVisual.LastUsedTransparency = nil
        ArmsVisual.LastUsedMaterial = nil
        ArmsVisual.LastViewModelCheck = nil
        
        ArmsVisual.CachedViewModel = model
        
        ArmsVisual.ViewModelChildrenConnection = model.DescendantAdded:Connect(function(child)
            if not ArmsVisual.Enabled then return end
            
            task.delay(0.05, function()
                if not ArmsVisual.Enabled then return end
                
                ArmsVisual.LastUsedColor = nil
                ArmsVisual.LastUsedTransparency = nil
                ArmsVisual.LastUsedMaterial = nil
                pcall(function()
                    UpdateArmsVisual(ArmsVisual.Color, ArmsVisual.Transparency)
                end)
            end)
        end)
    end
    
    ArmsVisual.WeaponChangeConnection = camera.ChildAdded:Connect(function(child)
        if shouldProcess(child) then
            task.delay(0.05, function()
                updateViewModel(child)
            end)
        end
    end)
    
    task.delay(0.05, function()
        for _, model in ipairs(camera:GetChildren()) do
            if shouldProcess(model) then
                updateViewModel(model)
                break
            end
        end
    end)
    
    return true
end

local function CleanupArmsVisualConnections()
    if not ArmsVisual then return end
    
    if ArmsVisual.Connection then
        ArmsVisual.Connection:Disconnect()
        ArmsVisual.Connection = nil
    end
    
    if ArmsVisual.WeaponChangeConnection then
        ArmsVisual.WeaponChangeConnection:Disconnect()
        ArmsVisual.WeaponChangeConnection = nil
    end
    
    if ArmsVisual.ViewModelChangeConnection then
        ArmsVisual.ViewModelChangeConnection:Disconnect()
        ArmsVisual.ViewModelChangeConnection = nil
    end
    
    ArmsVisual.CachedViewModel = nil
    ArmsVisual.LastViewModelCheck = nil
    ArmsVisual.LastUsedColor = nil
    ArmsVisual.LastUsedTransparency = nil
    ArmsVisual.LastUsedMaterial = nil
    ArmsVisual.SavedAppearances = {}
end


local PlayerHandSection = tabs.Player:Section({ Side = "Left", Name = "Hand Customization" })

PlayerHandSection:Header({
    Text = "Hand & Weapon Visual"
})


local function EmergencyDisableArmsVisual()
    
    ArmsVisual.Enabled = false
    
    
    if ArmsVisual.Connection then
        ArmsVisual.Connection:Disconnect()
        ArmsVisual.Connection = nil
    end
    
    if ArmsVisual.WeaponChangeConnection then
        ArmsVisual.WeaponChangeConnection:Disconnect()
        ArmsVisual.WeaponChangeConnection = nil
    end
    
    if ArmsVisual.WeaponRemoveConnection then
        ArmsVisual.WeaponRemoveConnection:Disconnect()
        ArmsVisual.WeaponRemoveConnection = nil
    end
    
    if ArmsVisual.ViewModelChangeConnection then
        ArmsVisual.ViewModelChangeConnection:Disconnect()
        ArmsVisual.ViewModelChangeConnection = nil
    end
    
    
    for stored, parent in pairs(ArmsVisual.SavedAppearances) do
        pcall(function()
            if stored and stored:IsA("Instance") and parent and parent:IsA("Instance") and parent.Parent then
                stored.Parent = parent
            end
        end)
    end
    
    
    ArmsVisual.SavedAppearances = {}
    ArmsVisual.CachedViewModel = nil
    ArmsVisual.LastViewModelCheck = nil
    ArmsVisual.LastUsedColor = nil
    ArmsVisual.LastUsedTransparency = nil
    ArmsVisual.LastUsedMaterial = nil
    
    
    pcall(function()
        for _, child in ipairs(workspace.Camera:GetDescendants()) do
            if child:IsA("BasePart") or child:IsA("MeshPart") or 
               child:IsA("Part") or child:IsA("UnionOperation") then
                pcall(function()
                    child.Material = Enum.Material.SmoothPlastic
                    child.Transparency = 0
                end)
            elseif child:IsA("Decal") or child:IsA("Texture") then
                pcall(function()
                    child.Transparency = 0
                end)
            elseif child:IsA("ParticleEmitter") or child:IsA("Beam") or child:IsA("Trail") then
                pcall(function()
                    child.Enabled = true
                    if child:IsA("ParticleEmitter") or child:IsA("Beam") or child:IsA("Trail") then
                        child.Transparency = NumberSequence.new(0)
                    end
                end)
            end
        end
    end)
    
    
    Window:Notify({
        Title = "Hand Visual",
        Description = "Hand Visual  - ",
        Lifetime = 5
    })
    
    
    pcall(function()
        if PlayerHandSection and PlayerHandSection.Objects and 
           PlayerHandSection.Objects["EnableHandSkin"] and 
           type(PlayerHandSection.Objects["EnableHandSkin"].Set) == "function" then
            PlayerHandSection.Objects["EnableHandSkin"]:Set(false)
        end
    end)
end
]]
