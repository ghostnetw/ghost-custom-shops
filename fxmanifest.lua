fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- Asegúrate de tener ox_lib y oxmysql como dependencias
dependency 'ox_lib'
dependency 'oxmysql'
dependency 'qb-core'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client.lua',
    'bossmenu.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- Asegura que oxmysql esté cargado antes
    'server.lua',
    'bossmenu.lua'
}

files {
    'config.lua'
}

