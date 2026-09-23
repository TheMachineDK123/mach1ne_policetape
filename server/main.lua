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

local function itemCost(pointCount)
    if not Config.ConsumeItem then return 0 end
    return Config.ItemPerSegment and pointCount - 1 or 1
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

lib.callback.register('mach1ne_policetape:canUse', function(source)
    if not isPolice(source) then return false, 'Kun politiet kan bruge afspærringstape' end
    local count = ox:GetItemCount(source, Config.Item)
    if count < 1 then return false, 'Du har ingen afspærringstape' end
    if Config.MaxTapesPerPlayer > 0 and countTapes(source) >= Config.MaxTapesPerPlayer then
        return false, ('Du har allerede sat %d afspærringer op'):format(Config.MaxTapesPerPlayer)
    end
    return true, count
end)

lib.callback.register('mach1ne_policetape:place', function(source, points)
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

    local cost = itemCost(#points)
    if ox:GetItemCount(source, Config.Item) < math.max(cost, 1) then
        return false, 'Du har ikke nok afspærringstape'
    end
    if cost > 0 and not ox:RemoveItem(source, Config.Item, cost) then
        return false, 'Kunne ikke bruge afspærringstape'
    end

    nextId = nextId + 1
    local tape = { id = nextId, points = points, owner = source, cost = cost, created = os.time() }
    Tapes[nextId] = tape
    TriggerClientEvent('mach1ne_policetape:add', -1, tape)
    return true
end)

RegisterNetEvent('mach1ne_policetape:remove', function(id)
    local src  = source
    local tape = Tapes[id]
    if not tape or not isPolice(src) then return end

    local pos, closest = GetEntityCoords(GetPlayerPed(src)), math.huge
    for _, point in ipairs(tape.points) do closest = math.min(closest, #(pos - point)) end
    if closest > Config.Remove.interactDist + 3.0 then return end

    removeTape(id)

    if Config.ReturnItem and tape.cost > 0 and ox:CanCarryItem(src, Config.Item, tape.cost) then
        ox:AddItem(src, Config.Item, tape.cost)
    end
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
