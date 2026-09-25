local ox     = exports.ox_inventory
local Tapes  = {}
local nextId = 0

local function isPolice(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    local job = xPlayer and xPlayer.job
    local minGrade = job and Config.Jobs[job.name]
    return minGrade ~= nil and job.grade >= minGrade
end

local function countTapes(src)
    local count = 0
    for _, tape in pairs(Tapes) do
        if tape.owner == src then count = count + 1 end
    end
    return count
end

local function getRoll(src, slot)
    local item = type(slot) == 'number' and ox:GetSlot(src, slot)
    if not item or item.name ~= Config.Item then
        slot = ox:GetSlotIdWithItem(src, Config.Item)
        item = slot and ox:GetSlot(src, slot)
    end
    return item, slot
end

local function getDurability(item)
    return (item.metadata and item.metadata.durability) or 100
end

local function removeTape(id)
    Tapes[id] = nil
    TriggerClientEvent('mach1ne_policetape:remove', -1, id)
end

lib.callback.register('mach1ne_policetape:getTapes', function()
    local list = {}
    for _, tape in pairs(Tapes) do list[#list + 1] = tape end
    return list
end)

lib.callback.register('mach1ne_policetape:canUse', function(source, slot)
    if not isPolice(source) then return false, 'Kun politiet kan bruge afspærringstape' end
    if Config.MaxTapesPerPlayer > 0 and countTapes(source) >= Config.MaxTapesPerPlayer then
        return false, ('Du har allerede sat %d afspærringer op'):format(Config.MaxTapesPerPlayer)
    end
    if not Config.ConsumeItem then return true, -1 end

    local item = getRoll(source, slot)
    if not item then return false, 'Du har ingen afspærringstape' end

    local remaining = getDurability(item) / 100 * Config.RollLength
    if remaining < Config.Tape.minLength then
        return false, 'Din afspærringstape er opbrugt'
    end
    return true, remaining
end)

lib.callback.register('mach1ne_policetape:place', function(source, points, slot)
    if not isPolice(source) then return false, 'Kun politiet kan bruge afspærringstape' end
    if type(points) ~= 'table' or #points < 2 or #points > Config.Tape.maxPoints then
        return false, 'Ugyldige punkter'
    end

    local total = 0.0
    for i = 1, #points do
        if type(points[i]) ~= 'vector3' then return false, 'Ugyldige punkter' end
        if i > 1 then
            local length = #(points[i] - points[i - 1])
            if length < Config.Tape.minLength or length > Config.Tape.maxLength then
                return false, 'Ugyldig længde på tapen'
            end
            total = total + length
        end
    end

    local pos = GetEntityCoords(GetPlayerPed(source))
    local maxDist = Config.Place.maxDistance + 3.0
    if #(pos - points[#points]) > maxDist then return false, 'Du er for langt væk' end
    for i = 1, #points do
        if #(pos - points[i]) > total + maxDist then return false, 'Du er for langt væk' end
    end

    if Config.MaxTapesPerPlayer > 0 and countTapes(source) >= Config.MaxTapesPerPlayer then
        return false, ('Du har allerede sat %d afspærringer op'):format(Config.MaxTapesPerPlayer)
    end

    local left
    if Config.ConsumeItem then
        local item, rollSlot = getRoll(source, slot)
        if not item then return false, 'Du har ingen afspærringstape' end

        local durability = getDurability(item)
        local remaining  = durability / 100 * Config.RollLength
        if total > remaining + 0.01 then
            return false, 'Der er ikke nok tape på rullen'
        end

        left = math.max(remaining - total, 0)
        local newDurability = durability - total / Config.RollLength * 100
        if newDurability <= 0 then
            ox:RemoveItem(source, Config.Item, 1, nil, rollSlot)
        else
            local metadata = item.metadata or {}
            metadata.durability = newDurability
            metadata.description = ('Tape tilbage: %.1f m'):format(left)
            ox:SetMetadata(source, rollSlot, metadata)
        end
    end

    nextId = nextId + 1
    local tape = { id = nextId, points = points, owner = source, created = os.time() }
    Tapes[nextId] = tape
    TriggerClientEvent('mach1ne_policetape:add', -1, tape)
    return true, left
end)

RegisterNetEvent('mach1ne_policetape:remove', function(id)
    local src  = source
    local tape = Tapes[id]
    if not tape or not isPolice(src) then return end

    local pos, closest = GetEntityCoords(GetPlayerPed(src)), math.huge
    for _, point in ipairs(tape.points) do closest = math.min(closest, #(pos - point)) end
    if closest > Config.Remove.interactDist + 3.0 then return end

    removeTape(id)
end)

if Config.Lifetime > 0 then
    CreateThread(function()
        while true do
            Wait(60000)
            local expire = os.time() - Config.Lifetime * 60
            for id, tape in pairs(Tapes) do
                if tape.created <= expire then removeTape(id) end
            end
        end
    end)
end
