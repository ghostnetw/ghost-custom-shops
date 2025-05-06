fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'TuNombre'
description 'Sistema de tiendas QBCore + ox_inventory + ox_lib'
version '1.0.0'

dependency 'ox_lib'
dependency 'ox_inventory'
dependency 'qb-core'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}
