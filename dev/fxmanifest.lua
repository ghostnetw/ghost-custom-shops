fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- Asegúrate de tener ox_lib y oxmysql como dependencias
dependency 'ox_lib'
dependency 'oxmysql'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua', -- Asegura que oxmysql esté cargado antes
    'server.lua'
}

files {
    'config.lua'
}

