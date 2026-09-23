local Tapes     = {}
local visible   = {}
local placing   = false
local handProps = {}
local TXD, TXN  = Config.Texture.dict, Config.Texture.name
local REPEAT    = Config.Tape.width * Config.Texture.aspect
local HALF      = Config.Tape.width * 0.5
local PROP_KEY  = 'mach1ne_policetape:prop'

local function isPolice(job)
    job = job or (ESX.PlayerData and ESX.PlayerData.job)
    local minGrade = job and Config.Jobs[job.name]
    return minGrade ~= nil and job.grade >= minGrade
end

local function loadTexture()
    if HasStreamedTextureDictLoaded(TXD) then return true end
    RequestStreamedTextureDict(TXD, false)
    local timeout = GetGameTimer() + 5000
    while not HasStreamedTextureDictLoaded(TXD) and GetGameTimer() < timeout do Wait(0) end
    return HasStreamedTextureDictLoaded(TXD)
end

local function toVec3(v) return vec3(v.x, v.y, v.z) end

local function isPathClear(a, b, ped)
    if not Config.Terrain.blockThroughWalls then return true end
    local dir = b - a
    local length = #dir
    if length <= 0.3 then return true end
    dir = dir / length
    local s, e = a + dir * 0.15, b - dir * 0.15
    local ray = StartExpensiveSynchronousShapeTestLosProbe(s.x, s.y, s.z, e.x, e.y, e.z,
        Config.Terrain.collisionFlags, ped or PlayerPedId(), 4)
    local _, hit = GetShapeTestResult(ray)
    return not hit or hit == 0
end

local function buildSegment(a, b)
    local dir    = b - a
    local length = #dir
    local sag    = math.min(length * Config.Tape.sagPerMeter, Config.Tape.maxSag)
    local step   = REPEAT / Config.Tape.subdivisions
    local flat   = math.sqrt(dir.x * dir.x + dir.y * dir.y)
    local px, py = 1.0, 0.0
    if flat > 0.001 then px, py = -dir.y / flat, dir.x / flat end

    local pts, d = {}, 0.0
    while true do
        local s   = d / length
        local p   = a + dir * s
        local env = 4.0 * s * (1.0 - s)
        local z   = p.z - sag * env

        if env > 0.0 then
            local found, groundZ = GetGroundZFor_3dCoord(p.x, p.y, p.z + 0.5, false)
            local minZ = groundZ + HALF + Config.Terrain.groundClearance
            if found and z < minZ then z = minZ end
        end

        pts[#pts + 1] = { x = p.x, y = p.y, z = z, d = d, env = env }
        if d >= length then break end
        d = math.min(d + step, length)
    end

    return { pts = pts, length = length, px = px, py = py, phase = (a.x + a.y) % 6.28 }
end

local bx, by, bz = {}, {}, {}

local function drawSegment(seg, r, g, b, a, time, windAmp)
    local pts = seg.pts
    local amp = windAmp * math.min(seg.length / 5.0, 1.0)

    for i = 1, #pts do
        local p = pts[i]
        local off, offZ = 0.0, 0.0
        if amp > 0.0 and p.env > 0.0 then
            local w = amp * p.env
            off  = math.sin(time + p.d * 1.7 + seg.phase) * w
            offZ = math.cos(time * 1.3 + p.d * 2.3 + seg.phase) * w * 0.35
        end
        bx[i], by[i], bz[i] = p.x + seg.px * off, p.y + seg.py * off, p.z + offZ
    end

    for i = 1, #pts - 1 do
        local k  = math.floor(pts[i].d / REPEAT + 1e-4)
        local u0 = pts[i].d / REPEAT - k
        local u1 = pts[i + 1].d / REPEAT - k
        local x0, y0, x1, y1 = bx[i], by[i], bx[i + 1], by[i + 1]
        local t0, b0 = bz[i] + HALF, bz[i] - HALF
        local t1, b1 = bz[i + 1] + HALF, bz[i + 1] - HALF

        DrawTexturedPoly(x0, y0, t0, x0, y0, b0, x1, y1, t1, r, g, b, a, TXD, TXN,
            u0, 0.0, 0.0, u0, 1.0, 0.0, u1, 0.0, 0.0)
        DrawTexturedPoly(x1, y1, t1, x0, y0, b0, x1, y1, b1, r, g, b, a, TXD, TXN,
            u1, 0.0, 0.0, u0, 1.0, 0.0, u1, 1.0, 0.0)

        local bu0, bu1 = 1.0 - u0, 1.0 - u1
        DrawTexturedPoly(x0, y0, t0, x1, y1, t1, x0, y0, b0, r, g, b, a, TXD, TXN,
            bu0, 0.0, 0.0, bu1, 0.0, 0.0, bu0, 1.0, 0.0)
        DrawTexturedPoly(x1, y1, t1, x1, y1, b1, x0, y0, b0, r, g, b, a, TXD, TXN,
            bu1, 0.0, 0.0, bu1, 1.0, 0.0, bu0, 1.0, 0.0)
    end
end

local function getWind()
    if not Config.Wind.enabled then return 0.0, 0.0 end
    local amp = math.min(Config.Wind.base + GetWindSpeed() * Config.Wind.perSpeed, Config.Wind.max)
    return GetGameTimer() / 1000.0 * Config.Wind.speed, amp
end

local function deleteHandProp(serverId)
    local obj = handProps[serverId]
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    handProps[serverId] = nil
end

local function setHandProp(state)
    if Config.Prop.enabled then LocalPlayer.state:set(PROP_KEY, state, true) end
end

AddStateBagChangeHandler(PROP_KEY, nil, function(bagName, _, value)
    local ply = GetPlayerFromStateBagName(bagName)
    if ply == 0 then return end
    local serverId = GetPlayerServerId(ply)
    deleteHandProp(serverId)
    if not value then return end

    CreateThread(function()
        local ped = GetPlayerPed(ply)
        if not DoesEntityExist(ped) then return end
        local model = lib.requestModel(Config.Prop.model)
        if not model then return end

        local c   = GetEntityCoords(ped)
        local obj = CreateObject(model, c.x, c.y, c.z + 0.2, false, false, false)
        local p, r = Config.Prop.pos, Config.Prop.rot
        SetEntityCollision(obj, false, true)
        AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, Config.Prop.bone), p.x, p.y, p.z, r.x, r.y, r.z,
            true, false, false, true, 2, true)
        SetModelAsNoLongerNeeded(model)

        deleteHandProp(serverId)
        handProps[serverId] = obj
    end)
end)

AddEventHandler('onPlayerDropped', function(serverId)
    deleteHandProp(serverId)
end)

local function removeBlip(tape)
    if tape.blip and DoesBlipExist(tape.blip) then RemoveBlip(tape.blip) end
    tape.blip = nil
end

local function createBlip(tape)
    removeBlip(tape)
    if not Config.Blip.enabled then return end
    local c    = tape.center
    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, Config.Blip.sprite)
    SetBlipColour(blip, Config.Blip.color)
    SetBlipScale(blip, Config.Blip.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blip.label)
    EndTextCommandSetBlipName(blip)
    tape.blip = blip
end

local function refreshBlips(job)
    local police = isPolice(job)
    for _, tape in pairs(Tapes) do
        if police then createBlip(tape) else removeBlip(tape) end
    end
end

RegisterNetEvent('esx:setJob', function(job) refreshBlips(job) end)
RegisterNetEvent('esx:playerLoaded', function(xPlayer) refreshBlips(xPlayer and xPlayer.job) end)

local function interactionId(id) return 'mach1ne_policetape_' .. id end

local function takeDown(id)
    setHandProp(true)
    local done = st.progressBar({
        duration     = Config.Remove.duration,
        label        = 'Tager afspærringstape ned...',
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
        anim         = Config.Place.anim,
    })
    setHandProp(false)
    if done then TriggerServerEvent('mach1ne_policetape:remove', id) end
end

local function addTape(data)
    if Tapes[data.id] then return end

    local points, segments = {}, {}
    local center = vec3(0.0, 0.0, 0.0)
    for i, p in ipairs(data.points) do
        points[i] = toVec3(p)
        center = center + points[i]
        if i > 1 then segments[#segments + 1] = buildSegment(points[i - 1], points[i]) end
    end
    center = center / #points

    local radius = 0.0
    for _, p in ipairs(points) do radius = math.max(radius, #(p - center)) end

    local tape = { id = data.id, points = points, segments = segments, center = center, radius = radius }
    Tapes[data.id] = tape

    local groupId = interactionId(data.id)
    local options = {}
    for i, coords in ipairs(points) do
        options[i] = {
            id           = ('%s_%d'):format(groupId, i),
            text         = 'Tag afspærring ned',
            displayDist  = Config.Remove.displayDist,
            interactDist = Config.Remove.interactDist,
            key          = 'E',
            keyNum       = 38,
            coords       = coords,
            canInteract  = function() return not placing and isPolice() end,
            onSelect     = function() takeDown(data.id) end,
        }
    end
    st.create3DTextUIOnCoords(groupId, options)

    if isPolice() then createBlip(tape) end
end

local function removeTape(id)
    local tape = Tapes[id]
    if not tape then return end
    removeBlip(tape)
    Tapes[id] = nil
    st.remove3DTextUIFromCoords(interactionId(id))
end

RegisterNetEvent('mach1ne_policetape:add', addTape)
RegisterNetEvent('mach1ne_policetape:remove', removeTape)

CreateThread(function()
    while true do
        local cam  = GetFinalRenderedCamCoord()
        local list = {}
        for _, tape in pairs(Tapes) do
            if #(cam - tape.center) <= Config.Tape.renderDistance + tape.radius then
                list[#list + 1] = tape
            end
        end
        if #list > 0 and not loadTexture() then list = {} end
        visible = list
        Wait(500)
    end
end)

CreateThread(function()
    local c = Config.Tape.color
    while true do
        if #visible > 0 then
            local time, amp = getWind()
            for i = 1, #visible do
                local segments = visible[i].segments
                for j = 1, #segments do drawSegment(segments[j], c[1], c[2], c[3], c[4], time, amp) end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

local function rotationToDirection(rot)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    return vec3(-math.sin(z) * math.abs(math.cos(x)), math.cos(z) * math.abs(math.cos(x)), math.sin(x))
end

local function getAimPoint(ped)
    local cam  = GetGameplayCamCoord()
    local dest = cam + rotationToDirection(GetGameplayCamRot(2)) * (#(cam - GetEntityCoords(ped)) + Config.Place.maxDistance + 2.0)
    local ray  = StartExpensiveSynchronousShapeTestLosProbe(cam.x, cam.y, cam.z, dest.x, dest.y, dest.z, 1 | 16, ped, 4)
    local _, hit, coords, normal = GetShapeTestResult(ray)
    if not hit or hit == 0 then return end

    if normal.z > 0.7 then
        return coords + vec3(0.0, 0.0, Config.Place.groundHeight)
    end
    return coords + normal * 0.02
end

local function drawPoint(pos, valid)
    local r, g = valid and 50 or 220, valid and 200 or 40
    DrawMarker(28, pos.x, pos.y, pos.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.07, 0.07, 0.07,
        r, g, 50, 200, false, false, 2, false, nil, nil, false)
end

local function showHelp(count, maxPoints)
    local lines = { ('[E] Sæt punkt (%d/%d)'):format(count + 1, maxPoints) }
    if count >= 2 then lines[#lines + 1] = '[Enter] Færdig' end
    lines[#lines + 1] = count > 0 and '[Backspace] Fortryd punkt' or '[Backspace] Annuller'
    lines[#lines + 1] = '[Højreklik] Annuller'
    lib.showTextUI(table.concat(lines, '  \n'), { icon = 'tape' })
end

local function selectPoints(maxPoints)
    local ped = PlayerPedId()
    local points, segments = {}, {}
    local c = Config.Tape.color

    showHelp(0, maxPoints)

    while true do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 140, true)
        DisableControlAction(0, 141, true)
        DisableControlAction(0, 142, true)

        if IsDisabledControlJustPressed(0, 25) or IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then
            lib.hideTextUI()
            return
        end

        if IsControlJustPressed(0, 194) then
            if #points == 0 then
                lib.hideTextUI()
                return
            end
            points[#points] = nil
            segments[#segments] = nil
            showHelp(#points, maxPoints)
        end

        if #points >= 2 and IsControlJustPressed(0, 191) then
            lib.hideTextUI()
            return points
        end

        local time, amp = getWind()
        for i = 1, #segments do drawSegment(segments[i], c[1], c[2], c[3], 200, time, amp) end
        for i = 1, #points do drawPoint(points[i], true) end

        local aim   = getAimPoint(ped)
        local valid = aim and #(GetEntityCoords(ped) - aim) <= Config.Place.maxDistance
        local last  = points[#points]

        if last and aim then
            local length = #(aim - last)
            valid = valid and length >= Config.Tape.minLength and length <= Config.Tape.maxLength
                and isPathClear(last, aim, ped)
            if length >= 0.05 then
                drawSegment(buildSegment(last, aim), valid and c[1] or 255, valid and c[2] or 90, valid and c[3] or 90, 150, time, 0.0)
            end
        end

        if aim then drawPoint(aim, valid) end

        if valid and IsControlJustPressed(0, 38) then
            if last then segments[#segments + 1] = buildSegment(last, aim) end
            points[#points + 1] = aim

            if #points >= maxPoints then
                lib.hideTextUI()
                return points
            end
            showHelp(#points, maxPoints)
        end
    end
end

local function startPlacing()
    if placing then return end
    if not isPolice() then
        return st.notify({ description = 'Kun politiet kan bruge afspærringstape', type = 'error' })
    end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        return st.notify({ description = 'Du kan ikke sætte tape op fra et køretøj', type = 'error' })
    end

    local canUse, result = lib.callback.await('mach1ne_policetape:canUse', false)
    if not canUse then return st.notify({ description = result, type = 'error' }) end
    if not loadTexture() then
        return st.notify({ description = 'Kunne ikke indlæse tape-texturen', type = 'error' })
    end

    local maxPoints = Config.Tape.maxPoints
    if Config.ConsumeItem and Config.ItemPerSegment then
        maxPoints = math.min(maxPoints, result + 1)
    end

    placing = true
    setHandProp(true)
    local points = selectPoints(maxPoints)

    if points then
        local done = st.progressBar({
            duration     = Config.Place.duration,
            label        = 'Sætter afspærringstape op...',
            useWhileDead = false,
            canCancel    = true,
            disable      = { move = true, car = true, combat = true },
            anim         = Config.Place.anim,
        })

        if done then
            local ok, err = lib.callback.await('mach1ne_policetape:place', false, points)
            st.notify(ok and { description = 'Afspærringstape sat op', type = 'success' }
                or { description = err or 'Kunne ikke sætte tape op', type = 'error' })
        end
    end

    setHandProp(false)
    placing = false
end

exports('useTape', function()
    startPlacing()
end)

CreateThread(function()
    for _, tape in ipairs(lib.callback.await('mach1ne_policetape:getTapes', false) or {}) do
        addTape(tape)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if placing then lib.hideTextUI() end
    setHandProp(false)
    for serverId in pairs(handProps) do deleteHandProp(serverId) end
    for id, tape in pairs(Tapes) do
        removeBlip(tape)
        st.remove3DTextUIFromCoords(interactionId(id))
    end
    SetStreamedTextureDictAsNoLongerNeeded(TXD)
end)
