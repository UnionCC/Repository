local CreateRenderObject, SetRenderProperty, GetRenderProperty, DestroyRenderObject;

if syn then
    CreateRenderObject, SetRenderProperty, GetRenderProperty, DestroyRenderObject = getupvalue(Drawing.new, 1), getupvalue(getupvalue(Drawing.new, 7).__newindex, 4), getupvalue(getupvalue(Drawing.new, 7).__index, 4), getupvalue(getupvalue(Drawing.new, 7).__index, 3);
else
    CreateRenderObject = function(object)
        return Drawing.new(object)
    end

    SetRenderProperty = function(object, property, value)
        object[property] = value
    end

    GetRenderProperty = function(object, property)
        return object[property]
    end

    DestroyRenderObject = function(object)
        if object then
			object:Remove()
		end
    end
end

local esp = {
    players = {},
    drawings = {},
    connections = {},
    
    enabled = false,
    ai = false,
    team_check = false,
    use_display_names = false,

    highlights = {
        target = {
            enabled = false,
            current = nil,
            color = Color3.fromRGB(255, 50, 50)
        }
    },

    settings = {
        name = {enabled = false, color = Color3.fromRGB(255, 255, 255)},
        box = {enabled = false, color = Color3.fromRGB(255, 255, 255)},
        health_bar = {enabled = false},
        health_text = {enabled = false, color = Color3.fromRGB(255, 255, 255)},
        distance = {enabled = false, color = Color3.fromRGB(255, 255, 255)},
        weapon = {enabled = false, color = Color3.fromRGB(255, 255, 255)}
    }
}

do --// functions
    do --// overrideable
        function esp.get_character(v)
            local character = v.Character or v
            if character then
                local head = character:FindFirstChild("Head")
                local torso = character:FindFirstChild("HumanoidRootPart")
                if head and torso then
                    return character
                end
            end
        end
    
        function esp.get_health(v)
            local character = esp.get_character(v)
            if character then
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    return humanoid.Health, humanoid.MaxHealth
                end
            end
        end
    
        function esp.is_alive(v)
            local character = esp.get_character(v)
            if character then
                local health, max_health = esp.get_health(v)
                if health and max_health then
                    if health > 0 then
                        return true
                    end
                end
            end
        end
    
        function esp.get_tool(v)
            local character = esp.get_character(v)
            if character then
                local tool = character:FindFirstChildOfClass("Tool")
                if tool then
                    return tostring(tool)
                end
                return ""
            end
        end
    
        function esp.check_team(v)
            if game.Players.LocalPlayer.Team == v.Team then
                return false
            end
            return true
        end
    end

    function esp:draw(object, properties)
        local drawing = CreateRenderObject(object)
        for i,v in pairs(properties) do
            SetRenderProperty(drawing, i, v)
        end
        esp.drawings[drawing] = drawing
        return drawing
    end

    function esp:connection(signal, callback)
        local con = signal:Connect(callback)
        esp.connections[con] = con
        return con
    end

    function esp:calculate_bounding_box(v)
        local cam = workspace.CurrentCamera.CFrame
        local torso = v.HumanoidRootPart.CFrame
        local head = v.Head.CFrame
        local top, top_isrendered = workspace.CurrentCamera:WorldToViewportPoint(head.Position + (torso.UpVector * 1))
        local bottom, bottom_isrendered = workspace.CurrentCamera:WorldToViewportPoint(torso.Position - (torso.UpVector * 2) - cam.UpVector)

        local minY = math.abs(bottom.y - top.y)
        local sizeX = math.ceil(math.max(math.clamp(math.abs(bottom.x - top.x) * 2.5, 0, minY), minY / 1.35, 6))
        local sizeY = math.ceil(math.max(minY, sizeX * 0.5, 10))

        if top_isrendered or bottom_isrendered then
            local boxtop = Vector2.new(math.floor(top.x * 0.5 + bottom.x * 0.5 - sizeX * 0.5), math.floor(math.min(top.y, bottom.y)))
            local boxsize = Vector2.new(sizeX, sizeY)
            return boxtop, boxsize 
        end
    end
    
    function esp:new_player(plr)
        esp.players[plr] = {
            name = esp:draw("Text", {Text = "OnlyTwentyCharacters", Font = 2, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), ZIndex = -100}),
            tool = esp:draw("Text", {Text = "None", Font = 2, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), ZIndex = -100}),
            health_text = esp:draw("Text", {Text = "100", Font = 2, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), ZIndex = -98}),
            distance = esp:draw("Text", {Text = "", Font = 2, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), ZIndex = -100}),
            weapon = esp:draw("Text", {Text = "", Font = 2, Size = 13, Center = true, Outline = true, Color = Color3.fromRGB(255, 255, 255), ZIndex = -100}),
            box_outline = esp:draw("Square", {Color = Color3.fromRGB(0, 0, 0), Thickness = 3, ZIndex = -100}),
            box = esp:draw("Square", {Color = Color3.fromRGB(255, 255, 255), Thickness = 1, ZIndex = -99}),
            health_outline = esp:draw("Line", {Thickness = 3, Color = Color3.fromRGB(0, 0, 0), ZIndex = -100}),
            health = esp:draw("Line", {Thickness = 1, Color = Color3.fromRGB(0, 255, 0), ZIndex = -99})
        }
    end

    function esp:update()
        for plr,espObjects in pairs(esp.players) do
            if esp.enabled or (plr.Parent ~= game.Players and esp.ai) then
                local character = esp.get_character(plr)
                local is_alive = esp.is_alive(plr)
                local health, max_health = esp.get_health(plr)
                local weapon_equipped = esp.get_tool(plr)
                local team_check = (plr.Parent == game.Players and esp.team_check and esp.check_team(plr)) or not esp.team_check
                if character and is_alive and team_check then
                    local _, onScreen = workspace.CurrentCamera:WorldToViewportPoint(character.PrimaryPart.Position)
                    if onScreen then
                        local BoxPos, BoxSize = esp:calculate_bounding_box(character)
                        if BoxPos and BoxSize then
                            local BottomOffset = 0
                            do --// Box
                                if esp.settings.box.enabled then
                                    SetRenderProperty(espObjects.box, "Position", BoxPos)
                                    SetRenderProperty(espObjects.box, "Size", Vector2.new(BoxSize.X, BoxSize.Y))
                                    SetRenderProperty(espObjects.box, "Color", esp.settings.box.color)

                                    if esp.highlights.target.enabled then
                                        if plr == esp.highlights.target.current then
                                            SetRenderProperty(espObjects.box, "Color", esp.highlights.target.color)
                                        end
                                    end
    
                                    SetRenderProperty(espObjects.box_outline, "Position", GetRenderProperty(espObjects.box, "Position"))
                                    SetRenderProperty(espObjects.box_outline, "Size", GetRenderProperty(espObjects.box, "Size"))
    
                                    SetRenderProperty(espObjects.box, "Visible", true)
                                    SetRenderProperty(espObjects.box_outline, "Visible", true)
                                else
                                    SetRenderProperty(espObjects.box, "Visible", false)
                                    SetRenderProperty(espObjects.box_outline, "Visible", false)
                                end
                            end
    
                            do --// Name
                                if esp.settings.name.enabled then
                                    SetRenderProperty(espObjects.name, "Text", plr.Parent == game.Players and esp.use_display_names and plr.DisplayName or plr.Name)
                                    SetRenderProperty(espObjects.name, "Position", BoxPos + Vector2.new(BoxSize.X/2, -GetRenderProperty(espObjects.name, "TextBounds").Y - 2))
                                    SetRenderProperty(espObjects.name, "Color", esp.settings.name.color)

                                    if esp.highlights.target.enabled then
                                        if plr == esp.highlights.target.current then
                                            SetRenderProperty(espObjects.name, "Color", esp.highlights.target.color)
                                        end
                                    end
    
                                    SetRenderProperty(espObjects.name, "Visible", true)
                                else
                                    SetRenderProperty(espObjects.name, "Visible", false)
                                end
                            end
    
                            do --// Health
                                if esp.settings.health_bar.enabled then
                                    SetRenderProperty(espObjects.health, "From", Vector2.new((BoxPos.X - GetRenderProperty(espObjects.health_outline, "Thickness") - 1), BoxPos.Y + BoxSize.Y))
                                    SetRenderProperty(espObjects.health, "To", Vector2.new(GetRenderProperty(espObjects.health, "From").X, GetRenderProperty(espObjects.health, "From").Y - (health / max_health) * BoxSize.Y))
                                    SetRenderProperty(espObjects.health, "Color", Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(0,255,0), health / max_health))
    
                                    SetRenderProperty(espObjects.health_outline, "From", GetRenderProperty(espObjects.health, "From") + Vector2.new(0, 1))
                                    SetRenderProperty(espObjects.health_outline, "To", Vector2.new(GetRenderProperty(espObjects.health_outline, "From").X, BoxPos.Y - 1))
    
                                    SetRenderProperty(espObjects.health, "Visible", true)
                                    SetRenderProperty(espObjects.health_outline, "Visible", true)
                                else
                                    SetRenderProperty(espObjects.health, "Visible", false)
                                    SetRenderProperty(espObjects.health_outline, "Visible", false)
                                end
                            end
    
                            do --// Health Text
                                if esp.settings.health_text.enabled then
                                    SetRenderProperty(espObjects.health_text, "Text", tostring(math.floor(health)))
                                    SetRenderProperty(espObjects.health_text, "Position", Vector2.new((BoxPos.X - GetRenderProperty(espObjects.health_outline, "Thickness") - 1), BoxPos.Y + BoxSize.Y - (health / max_health) * BoxSize.Y) + Vector2.new(-GetRenderProperty(espObjects.name, "TextBounds").Y, 0))
                                    SetRenderProperty(espObjects.health_text, "Color", esp.settings.health_text.color)

                                    if esp.highlights.target.enabled then
                                        if plr == esp.highlights.target.current then
                                            SetRenderProperty(espObjects.health_text, "Color", esp.highlights.target.color)
                                        end
                                    end
    
                                    SetRenderProperty(espObjects.health_text, "Visible", true)
                                else
                                    SetRenderProperty(espObjects.health_text, "Visible", false)
                                end
                            end

                            do --// Distance
                                if esp.settings.distance.enabled then
                                    SetRenderProperty(espObjects.distance, "Text", tostring(math.round((character.PrimaryPart.Position - workspace.CurrentCamera.CFrame.p).Magnitude / 3)) .. " meters")
                                    SetRenderProperty(espObjects.distance, "Position", BoxPos + Vector2.new(BoxSize.X/2, BoxSize.Y + 1))
                                    SetRenderProperty(espObjects.distance, "Color", esp.settings.distance.color)

                                    if esp.highlights.target.enabled then
                                        if plr == esp.highlights.target.current then
                                            SetRenderProperty(espObjects.distance, "Color", esp.highlights.target.color)
                                        end
                                    end

                                    BottomOffset = BottomOffset + (esp.settings.distance.enabled and 13) or 0
    
                                    SetRenderProperty(espObjects.distance, "Visible", true)
                                else
                                    SetRenderProperty(espObjects.distance, "Visible", false)
                                end
                            end
    
                            do --// Weapon
                                if esp.settings.weapon.enabled then
                                    SetRenderProperty(espObjects.weapon, "Text", weapon_equipped)
                                    SetRenderProperty(espObjects.weapon, "Position", BoxPos + Vector2.new(BoxSize.X/2, BoxSize.Y + BottomOffset))
                                    SetRenderProperty(espObjects.weapon, "Color", esp.settings.weapon.color)

                                    if esp.highlights.target.enabled then
                                        if plr == esp.highlights.target.current then
                                            SetRenderProperty(espObjects.weapon, "Color", esp.highlights.target.color)
                                        end
                                    end
    
                                    SetRenderProperty(espObjects.weapon, "Visible", true)
                                else
                                    SetRenderProperty(espObjects.weapon, "Visible", false)
                                end
                            end

                        else
                            for _,v in pairs(espObjects) do
                                SetRenderProperty(v, "Visible", false)
                            end
                        end
                    else
                        for _,v in pairs(espObjects) do
                            SetRenderProperty(v, "Visible", false)
                        end
                    end
                else
                    for _,v in pairs(espObjects) do
                        SetRenderProperty(v, "Visible", false)
                    end
                end
            else
                for _,v in pairs(espObjects) do
                    SetRenderProperty(v, "Visible", false)
                end
            end
        end
    end

    function esp:unload()
        for i,v in next, esp.connections do
            v:Disconnect()
        end
        for i,v in next, esp.drawings do
            v:Remove()
        end
    end
end

do --// object creation
    for _,v in pairs(game.Players:GetPlayers()) do
        if v ~= game.Players.LocalPlayer then
            esp:new_player(v)
        end
    end
    
    esp:connection(game.Players.PlayerAdded, function(player)
        esp:new_player(player)
    end)
    
    esp:connection(game.Players.PlayerRemoving, function(player)
        for i,v in pairs(esp.players[player]) do
            DestoryRenderObject(v)
        end
        esp.players[player] = nil
    end)
end

esp:connection(game.RunService.RenderStepped, function()
    esp:update()
end)

getgenv().esp = esp
