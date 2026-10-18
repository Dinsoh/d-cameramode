fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Dinsoh Development'
description 'Inventory instant photography for QB-Core and QS-Inventory'
version '0.3.0'
dependencies { 'qb-core', 'qs-inventory', 'screenshot-basic' }
shared_script 'config.lua'
client_script 'client.lua'
server_scripts { 'storage.js', 'inventory.lua', 'server.lua' }
ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js', 'html/photo.js' }
