-- Merge these entries into qb-core/shared/items.lua, inside QBShared.Items.
-- Keep names synchronized with Config.Items. The supplied QS QB bridge reads
-- QBCore.Shared.Items, not qs-inventory/shared/items.lua (that file is for ESX).
['polaroid_camera'] = {
    name = 'polaroid_camera', label = 'Instant Camera', weight = 350,
    type = 'item', image = 'polaroid_camera.png', unique = false, stack = true,
    useable = true, shouldClose = true, decay = 0.0, delete = false, description = 'Frame a moment and print a photograph.'
},
['polaroid_film'] = {
    name = 'polaroid_film', label = 'Instant Film', weight = 15,
    type = 'item', image = 'polaroid_film.png', unique = false, stack = true,
    useable = false, shouldClose = false, decay = 0.0, delete = false, description = 'One exposure for an instant photograph.'
},
['polaroid_photo'] = {
    name = 'polaroid_photo', label = 'Photograph', weight = 5,
    type = 'item', image = 'polaroid_photo.png', unique = true, stack = false,
    useable = true, shouldClose = true, decay = 0.0, delete = false, description = 'A printed moment. Use to view the photograph.'
},
