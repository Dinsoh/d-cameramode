-- Optional: append inside Config.ItemMetadata in qs-inventory/config/metadata.lua.
-- Keep the name synchronized if Config.Items.photo is changed. Do not replace
-- the entire existing metadata config. No private character ID is displayed.
polaroid_photo = {
    fields = {
        { label = 'Photographer', value = 'photographer' },
        { label = 'Taken', value = 'takenAt' },
    }
},
