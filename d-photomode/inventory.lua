-- QS exports/signatures and the QB item snapshot were verified in the supplied
-- AddItem.lua, RemoveItem.lua and server/custom/framework/qb.lua. No guessed APIs.
PhotoInventory = {}
local QBCore = exports['qb-core']:GetCoreObject()
local function items(src)
    local player = QBCore.Functions.GetPlayer(src)
    return player and player.PlayerData.items
end
function PhotoInventory.find(src, name, photoId)
    for slot, item in pairs(items(src) or {}) do
        if item.name == name and (item.amount or item.count or 0) > 0
            and (not photoId or type(item.info) == 'table' and item.info.photoId == photoId) then
            return item, tonumber(slot) or item.slot
        end
    end
end
function PhotoInventory.count(src, name)
    local count = 0
    for _, item in pairs(items(src) or {}) do
        if item.name == name then count = count + (item.amount or item.count or 0) end
    end
    return count
end
function PhotoInventory.ready(src)
    return GetResourceState(Config.InventoryResource) == 'started' and type(items(src)) == 'table'
end
function PhotoInventory.hasCamera(src)
    return PhotoInventory.ready(src) and PhotoInventory.find(src, Config.Items.camera) ~= nil
end
function PhotoInventory.film(src)
    local item, slot = PhotoInventory.find(src, Config.Items.film)
    if not item then return end
    -- Preserve exact metadata for a failed-print refund; never trust client fields.
    return {slot = slot, info = json.decode(json.encode(item.info or {})), created = item.created}
end
function PhotoInventory.removeFilm(src, film)
    local inventory = items(src)
    local item = inventory and inventory[film.slot]
    if not item or item.name ~= Config.Items.film or (item.amount or 0) < 1 then return false end
    local before = PhotoInventory.count(src, Config.Items.film)
    pcall(function() exports[Config.InventoryResource]:RemoveItem(src, Config.Items.film, 1, film.slot) end)
    return PhotoInventory.count(src, Config.Items.film) == before - 1
end
function PhotoInventory.sameOwner(src, owner)
    local player = QBCore.Functions.GetPlayer(src)
    return player and player.PlayerData.citizenid == owner
end
function PhotoInventory.refundFilm(src, film, owner)
    if not PhotoInventory.ready(src) or owner and not PhotoInventory.sameOwner(src, owner) then return false end
    local before = PhotoInventory.count(src, Config.Items.film)
    pcall(function()
        exports[Config.InventoryResource]:AddItem(src, Config.Items.film, 1, nil, film.info, nil, film.created)
    end)
    return PhotoInventory.count(src, Config.Items.film) == before + 1
end
function PhotoInventory.addPhoto(src, photo)
    if not PhotoInventory.ready(src) or PhotoInventory.find(src, Config.Items.photo, photo.id) then return false end
    local info = {photoId = photo.id, url = photo.url, takenAt = photo.takenAt, photographer = photo.photographer}
    pcall(function() exports[Config.InventoryResource]:AddItem(src, Config.Items.photo, 1, nil, info) end)
    return PhotoInventory.find(src, Config.Items.photo, photo.id) ~= nil
end
function PhotoInventory.removePhoto(src, id)
    local item, slot = PhotoInventory.find(src, Config.Items.photo, id)
    if not item or item.amount ~= 1 then return false end
    pcall(function() exports[Config.InventoryResource]:RemoveItem(src, Config.Items.photo, 1, slot) end)
    return PhotoInventory.find(src, Config.Items.photo, id) == nil
end
function PhotoInventory.currentPhoto(src, item)
    if type(item) ~= 'table' or not tonumber(item.slot) then return end
    local inventory = items(src)
    local current = inventory and inventory[tonumber(item.slot)]
    if not current or current.name ~= Config.Items.photo or (current.amount or 0) ~= 1 or type(current.info) ~= 'table' then return end
    if type(current.info.photoId) ~= 'string' or #current.info.photoId ~= 36 then return end
    return current.info.photoId
end
function PhotoInventory.definitionsValid()
    local camera, photo, film = QBCore.Shared.Items[Config.Items.camera], QBCore.Shared.Items[Config.Items.photo], QBCore.Shared.Items[Config.Items.film]
    return camera and photo and photo.unique == true and photo.stack ~= true and (not Config.RequireFilm or film)
end
