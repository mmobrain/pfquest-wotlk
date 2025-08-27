-- table.getn doesn't return sizes on tables that
-- are using a named index on which setn is not updated
local function tablesize(tbl)
  local count = 0
  for _ in pairs(tbl) do count = count + 1 end
  return count
end

function modulo(val, by)
  return val - math.floor(val/by)*by;
end

pfQuest.route = CreateFrame("Frame", "pfQuestRoute", WorldFrame)
pfQuest.route.firstnode = nil
pfQuest.route.coords = {}

-- Create drawing frames immediately to prevent parent frames from being nil
pfQuest.route.drawlayer = CreateFrame("Frame", "pfQuestRouteDrawLayer", WorldMapButton)
pfQuest.route.drawlayer:SetFrameLevel(113)
pfQuest.route.drawlayer:SetAllPoints()
WorldMapButton.routes = CreateFrame("Frame", "pfQuestRouteDisplay", pfQuest.route.drawlayer)
WorldMapButton.routes:SetAllPoints()

local objectivepath, playerpath, mplayerpath = {}, {}, {}
local linePool = {}

-- For tracking the manually set target node
local targetTitle, targetCluster, targetLayer, targetTexture

-- Helper to convert hex color string to RGB values (0-1)
local function hex_to_rgb(hex)
    hex = hex or pfQuest_config.routecolor or "D4AF37"
    local sanitized_hex = string.gsub(hex, "[^0-9a-fA-F]", "")
    if string.len(sanitized_hex) ~= 6 then
        return 212/255, 175/255, 55/255 -- default color "D4AF37"
    end
    local r = tonumber("0x" .. sanitized_hex:sub(1,2)) / 255
    local g = tonumber("0x" .. sanitized_hex:sub(3,4)) / 255
    local b = tonumber("0x" .. sanitized_hex:sub(5,6)) / 255
    return r, g, b
end

--------------------------------------------------------------------------------
-- START: Line Drawing Logic (Adapted from Routes addon)
--------------------------------------------------------------------------------
local TAXIROUTE_LINEFACTOR = 128/126
local TAXIROUTE_LINEFACTOR_2 = TAXIROUTE_LINEFACTOR / 2

local function _Internal_DrawRotatedLine(T, C, sx, sy, ex, ey, w, color, layer)
    T:SetDrawLayer(layer or "ARTWORK")
    T:SetVertexColor(color[1], color[2], color[3], color[4])
    local dx, dy = ex - sx, ey - sy
    local l = (dx * dx + dy * dy) ^ 0.5
    if l == 0 then
        T:Hide()
        return T;
    end
    local cx, cy = (sx + ex) / 2, (sy + ey) / 2
    if (dx < 0) then
        dx, dy = -dx, -dy
    end
    local s, c = -dy / l, dx / l
    local sc = s * c
    local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
    if (dy >= 0) then
        Bwid = ((l * c) - (w * s)) * TAXIROUTE_LINEFACTOR_2; Bhgt = ((w * c) - (l * s)) * TAXIROUTE_LINEFACTOR_2
        BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc; BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx; TRy = BRx
    else
        Bwid = ((l * c) + (w * s)) * TAXIROUTE_LINEFACTOR_2; Bhgt = ((w * c) + (l * s)) * TAXIROUTE_LINEFACTOR_2
        BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc; BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy; TRx = TLy
    end
    local function clamp(val) if val > 10000 then return 10000 elseif val < -10000 then return -10000 else return val end end
    TLx, TLy = clamp(TLx), clamp(TLy); BLx, BLy = clamp(BLx), clamp(BLy); TRx, TRy = clamp(TRx), clamp(TRy); BRx, BRy = clamp(BRx), clamp(BRy)
    T:ClearAllPoints(); T:SetTexCoord(TLx, TLy, BLx, BLy, TRx, TRy, BRx, BRy)
    T:SetPoint("BOTTOMLEFT", C, "BOTTOMLEFT", cx - Bwid, cy - Bhgt); T:SetPoint("TOPRIGHT", C, "BOTTOMLEFT", cx + Bwid, cy + Bhgt)
    T:Show(); return T
end

local function HideLines(parent)
    if parent and parent.pfQuest_Lines_Used then
        for i = #parent.pfQuest_Lines_Used, 1, -1 do
            local texture = table.remove(parent.pfQuest_Lines_Used)
            texture:Hide()
            table.insert(parent.pfQuest_Lines, texture)
        end
    end
end

local function AcquireLine(minimap)
    local parent = minimap and pfMap.drawlayer or WorldMapButton.routes
    if not parent then return nil end
    if not parent.pfQuest_Lines then parent.pfQuest_Lines = {}; parent.pfQuest_Lines_Used = {} end
    local texture = table.remove(parent.pfQuest_Lines) or parent:CreateTexture(nil, "ARTWORK")
    texture:SetTexture(pfQuestConfig.path.."\\img\\route_line"); texture:SetBlendMode("ADD")
    table.insert(parent.pfQuest_Lines_Used, texture)
    return texture
end
--------------------------------------------------------------------------------
-- END: Line Drawing Logic
--------------------------------------------------------------------------------

local function GetNearest(xstart, ystart, db, blacklist)
    local nearest, best = nil, nil
    for id, data in pairs(db) do
        if data[1] and data[2] and not blacklist[id] then
            local d = math.sqrt((xstart - data[1])^2 + (ystart - data[2])^2)
            if not nearest or d < nearest then nearest, best = d, id end
        end
    end
    if best then blacklist[best] = true; return db[best] end
end

local function DrawLine(path, x, y, nx, ny, hl, minimap, segment_idx, total_segments)
    local line = AcquireLine(minimap)
    if not line then return end
    local parent = line:GetParent(); local startX, startY, endX, endY; local width, color
    local r, g, b = hex_to_rgb(); local alpha = 1.0
    if not hl and pfQuest_config.progressivetransparency == "1" and segment_idx and total_segments and total_segments > 2 then
        local progress = (segment_idx - 2) / (total_segments - 2)
        alpha = 1.0 - (progress * 0.7)
    end
    if minimap then
        local pX, pY = GetPlayerMapPosition("player"); if pX == 0 and pY == 0 then line:Hide(); return end
        pX, pY = pX * 100, pY * 100
        local mapID = pfMap:GetMapIDByName(GetRealZoneText()); if not mapID or not pfMap.minimap_sizes[mapID] then line:Hide(); return end
        local mZoom = pfMap.drawlayer:GetZoom(); local mapZoom = pfMap.minimap_zoom[pfMap.minimap_indoor()][mZoom]
        local mapW, mapH = pfMap.minimap_sizes[mapID][1] or 0, pfMap.minimap_sizes[mapID][2] or 0
        if mapW == 0 or mapH == 0 then line:Hide(); return end
        local sX, sY = mapZoom / mapW, mapZoom / mapH
        local drawW, drawH = parent:GetWidth() / sX / 100, parent:GetHeight() / sY / 100
        local offsetX, offsetY = (x - pX) * drawW, (y - pY) * drawH
        local endOffsetX, endOffsetY = (nx - pX) * drawW, (ny - pY) * drawH
        startX, startY = parent:GetWidth()/2 + offsetX, parent:GetHeight()/2 - offsetY
        endX, endY = parent:GetWidth()/2 + endOffsetX, parent:GetHeight()/2 - endOffsetY
        local centerX, centerY = parent:GetWidth() / 2, parent:GetHeight() / 2
        local radius = centerX - 8
        local vecX, vecY = endX - centerX, endY - centerY
        local distance = (vecX^2 + vecY^2)^0.5
        if distance > radius then
            local scale = radius / distance
            endX = centerX + vecX * scale; endY = centerY + vecY * scale
        end
        width = 3; local minimap_alpha = hl and 0.9 or 0.7; color = {r, g, b, minimap_alpha}
    else
        local w, h = parent:GetWidth(), parent:GetHeight()
        startX, startY = (x / 100) * w, h - ((y / 100) * h)
        endX, endY = (nx / 100) * w, h - ((ny / 100) * h)
        width = 5; local worldmap_alpha = hl and 1.0 or alpha; color = {r, g, b, worldmap_alpha}
    end
    _Internal_DrawRotatedLine(line, parent, startX, startY, endX, endY, width, color, "ARTWORK")
    table.insert(path, line)
end

pfQuest.route.Reset = function(self) self.coords, self.firstnode, self.cachedRoute = {}, nil, nil end
pfQuest.route.AddPoint = function(self, tbl) table.insert(self.coords, tbl); self.firstnode = nil end

pfQuest.route.SetTarget = function(node, default)
  if node and (node.title~=targetTitle or node.cluster~=targetCluster or node.layer~=targetLayer or node.texture~=targetTexture) then pfMap.queue_update = true end
  targetTitle, targetCluster, targetLayer, targetTexture = node and node.title, node and node.cluster, node and node.layer, node and node.texture
end

pfQuest.route.IsTarget = function(node)
  if node and targetTitle and targetTitle==node.title and targetCluster==node.cluster and targetLayer==node.layer and targetTexture==node.texture then return true end
end

local lastpos, completed = 0, 0
local function sortfunc(a,b) return a[4] < b[4] end
pfQuest.route:SetScript("OnUpdate", function(self)
    local pX, pY = GetPlayerMapPosition("player")
    local wrongmap = pX == 0 and pY == 0
    local curpos = pX + pY

    if (self.tick or 0) > GetTime() and lastpos == curpos then return else self.tick = GetTime() + 0.5 end
    if (self.throttle or 0) > GetTime() then return else self.throttle = GetTime() + 0.05 end
    lastpos = curpos

    for id, data in ipairs(self.coords) do data[4] = math.sqrt((pX * 100 - data[1])^2 + (pY * 100 - data[2])^2) end
    table.sort(self.coords, sortfunc)

    if not self.recalculate or self.recalculate < GetTime() then
        if targetTitle and self.coords[1] and not pfQuest.route.IsTarget(self.coords[1][3]) then
            local target_idx
            for id, data in ipairs(self.coords) do if pfQuest.route.IsTarget(data[3]) then target_idx = id; break end end
            if target_idx then
                local target_node = table.remove(self.coords, target_idx)
                table.insert(self.coords, 1, target_node)
            end
        end
        self.recalculate = GetTime() + 1
    end

    local new_nearest = self.coords[1]
    local needs_recalc = false

    if new_nearest then
        if not self.cachedRoute or not self.firstnode then
            needs_recalc = true
        else
            local old_nearest = self.cachedRoute[1]
            if old_nearest ~= new_nearest then
                local dist_to_old = -1
                for _, node in ipairs(self.coords) do if node == old_nearest then dist_to_old = node[4]; break end end
                if dist_to_old == -1 or dist_to_old < 5.0 or (targetTitle and self.coords[1] ~= old_nearest) or (not targetTitle and new_nearest[4] < (dist_to_old * 0.85)) then
                    needs_recalc = true
                end
            end
        end
    else
        self.cachedRoute = nil; self.firstnode = nil
    end

    if needs_recalc and self.coords[1] then
        self.firstnode = tostring(self.coords[1][1] .. self.coords[1][2])
        local route, blacklist = {[1] = self.coords[1]}, {[1] = true}
        for i = 2, tablesize(self.coords) do
            if route[i-1] then route[i] = GetNearest(route[i-1][1], route[i-1][2], self.coords, blacklist) end
            if route[i] and route[i][3] and route[i][3].itemreq then
                for id, data in ipairs(self.coords) do
                    if not blacklist[id] and data[3] and data[3].itemreq == route[i][3].itemreq then blacklist[id] = true end
                end
            end
        end
        self.cachedRoute = route
        completed = GetTime()
    end

    HideLines(WorldMapButton.routes); HideLines(pfMap.drawlayer)

    if not wrongmap and self.cachedRoute and self.cachedRoute[1] and not self.arrow:IsShown() and pfQuest_config["arrow"] == "1" and GetTime() > (completed or 0) + 1 then self.arrow:Show() end
    if wrongmap or not self.cachedRoute or not self.cachedRoute[1] or pfQuest_config["routes"] == "0" then return end

    if self.cachedRoute and WorldMapFrame and WorldMapFrame:IsShown() then
        local total_segments = #self.cachedRoute
        for i = 2, total_segments do
            local p1, p2 = self.cachedRoute[i-1], self.cachedRoute[i]
            if p1 and p2 then DrawLine(objectivepath, p1[1], p1[2], p2[1], p2[2], false, false, i, total_segments) end
        end
        DrawLine(playerpath, pX * 100, pY * 100, self.cachedRoute[1][1], self.cachedRoute[1][2], true)
    end
    if pfQuest_config["routeminimap"] == "1" then DrawLine(mplayerpath, pX * 100, pY * 100, self.cachedRoute[1][1], self.cachedRoute[1][2], true, true) end
end)

pfQuest.route.arrow = CreateFrame("Frame", "pfQuestRouteArrow", UIParent)
pfQuest.route.arrow:SetPoint("CENTER", 0, -100)
pfQuest.route.arrow:SetWidth(48); pfQuest.route.arrow:SetHeight(36)
pfQuest.route.arrow:SetClampedToScreen(true); pfQuest.route.arrow:SetMovable(true); pfQuest.route.arrow:EnableMouse(true)
pfQuest.route.arrow:RegisterForDrag('LeftButton')
pfQuest.route.arrow:SetScript("OnDragStart", function() if IsShiftKeyDown() then this:StartMoving() end end)
pfQuest.route.arrow:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

local invalid, lasttarget
local defcolor = "|cffffcc00"

pfQuest.route.arrow:SetScript("OnUpdate", function(self)
    if not self.parent then return end

    local pX, pY = GetPlayerMapPosition("player")
    local wrongmap = (pX == 0 and pY == 0)

    local target
    if self.parent.cachedRoute and self.parent.cachedRoute[1] then
        target = self.parent.cachedRoute[1]
    elseif self.parent.coords and self.parent.coords[1] then
        target = self.parent.coords[1]
    end

    if not target or wrongmap or pfQuest_config["arrow"] == "0" then
        if invalid and invalid < GetTime() then
            self:Hide()
        elseif not invalid then invalid = GetTime() + 1 end
        return
    else invalid = nil end

    if not self:IsShown() then self:Show() end

    -- Calculate direction vector
    local xd = target[1] - pX * 100
    local yd = target[2] - pY * 100

    -- Get target angle (CCW from North) and player facing (CW from North)
    local targetAngle = math.atan2(xd, -yd)
    local playerFacing = pfQuestCompat.GetPlayerFacing()

    -- Calculate relative angle.
    -- Target angle is CCW, player facing is CW.
    -- To find the difference in a common system, we can add them.
    -- The result is a CCW angle from the player's forward direction.
    -- The texture atlas wants a CW angle, so we negate the result.
    local relativeAngle = -(targetAngle + playerFacing)

    local textureAngle = relativeAngle
    if textureAngle < 0 then textureAngle = textureAngle + (2 * math.pi) end

    local colorAngle = relativeAngle
    if colorAngle > math.pi then colorAngle = colorAngle - (2 * math.pi) end
    if colorAngle < -math.pi then colorAngle = colorAngle + (2 * math.pi) end

    local perc = (math.pi - math.abs(colorAngle)) / math.pi

    local r, g, b
    if perc < 0.5 then r = 1; g = perc * 2; b = 0
    else r = (1.0 - perc) * 2; g = 1; b = 0 end

    local cell = floor(textureAngle / (math.pi * 2) * 108 + 0.5)
    cell = modulo(cell, 108)

    local col, row = modulo(cell, 9), floor(cell / 9)

    local xs, ys = (col * 56) / 512, (row * 42) / 512
    local xe, ye = ((col + 1) * 56) / 512, ((row + 1) * 42) / 512

    local distance = target[4] or math.sqrt(xd*xd + yd*yd)

    local area = target[3].priority or 1
    area = max(1, area)
    area = min(20, area)
    area = (area / 10) + 1

    local alpha = distance / 100 - area
    alpha = (alpha > 1) and 1 or alpha
    alpha = (alpha < 0.8) and 0.8 or alpha

    local ta = (1 - alpha) * 2
    ta = (ta > 1) and 1 or ta
    ta = (ta < 0) and 0 or ta

    self.model:SetTexCoord(xs, xe, ys, ye)
    self.model:SetVertexColor(r, g, b)
    self.model:SetAlpha(alpha)

    if target ~= lasttarget then
        local color = defcolor
        if tonumber(target[3].qlvl) then color = pfMap:HexDifficultyColor(tonumber(target[3].qlvl)) end
        if target[3].texture then
            self.texture:SetTexture(target[3].texture)
            if target[3].vertex and (target[3].vertex[1] > 0 or target[3].vertex[2] > 0 or target[3].vertex[3] > 0) then
                self.texture:SetVertexColor(unpack(target[3].vertex))
            else self.texture:SetVertexColor(1, 1, 1, 1) end
        else
            self.texture:SetTexture(pfQuestConfig.path .. "\\img\\node")
            self.texture:SetVertexColor(pfMap.str2rgb(target[3].title))
        end
        local level = target[3].qlvl and "[" .. target[3].qlvl .. "] " or ""
        self.title:SetText(color .. level .. target[3].title .. "|r")
        local desc = target[3].description or ""
        if not pfUI or not pfUI.uf then
            self.description:SetTextColor(1, 0.9, 0.7, 1)
            desc = string.gsub(desc, "ff33ffcc", "ffffffff")
        end
        self.description:SetText(desc .. "|r."); lasttarget = target
    end

    local dist = floor(distance)
    if dist ~= (self.distance.number or 0) then
        self.distance:SetText("|cffaaaaaa" .. pfQuest_Loc["Distance"] .. ": " .. dist)
        self.distance.number = dist
    end
    self.texture:SetAlpha(1.0)
end)

-- Arrow model (the actual arrow image)
pfQuest.route.arrow.model = pfQuest.route.arrow:CreateTexture(nil, "MEDIUM")
pfQuest.route.arrow.model:SetTexture(pfQuestConfig.path.."\\img\\arrow")
pfQuest.route.arrow.model:SetAllPoints()

-- Quest objective icon
pfQuest.route.arrow.texture = pfQuest.route.arrow:CreateTexture(nil, "OVERLAY")
pfQuest.route.arrow.texture:SetWidth(22); pfQuest.route.arrow.texture:SetHeight(22)
pfQuest.route.arrow.texture:SetPoint("CENTER", pfQuest.route.arrow.model, "CENTER", 30, 0)

-- Text elements
pfQuest.route.arrow.title = pfQuest.route.arrow:CreateFontString(nil, "HIGH", "GameFontWhite")
pfQuest.route.arrow.title:SetPoint("TOP", pfQuest.route.arrow.model, "BOTTOM", 0, -10)
pfQuest.route.arrow.title:SetFont(pfUI.font_default, pfUI_config.global.font_size+1, "OUTLINE")
pfQuest.route.arrow.title:SetTextColor(1,.8,0); pfQuest.route.arrow.title:SetJustifyH("CENTER")

pfQuest.route.arrow.description = pfQuest.route.arrow:CreateFontString(nil, "HIGH", "GameFontWhite")
pfQuest.route.arrow.description:SetPoint("TOP", pfQuest.route.arrow.title, "BOTTOM", 0, -2)
pfQuest.route.arrow.description:SetFont(pfUI.font_default, pfUI_config.global.font_size, "OUTLINE")
pfQuest.route.arrow.description:SetTextColor(1,1,1); pfQuest.route.arrow.description:SetJustifyH("CENTER")

pfQuest.route.arrow.distance = pfQuest.route.arrow:CreateFontString(nil, "HIGH", "GameFontWhite")
pfQuest.route.arrow.distance:SetPoint("TOP", pfQuest.route.arrow.description, "BOTTOM", 0, -2)
pfQuest.route.arrow.distance:SetFont(pfUI.font_default, pfUI_config.global.font_size-1, "OUTLINE")
pfQuest.route.arrow.distance:SetTextColor(.8,.8,.8); pfQuest.route.arrow.distance:SetJustifyH("CENTER")

pfQuest.route.arrow.parent = pfQuest.route