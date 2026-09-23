fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'TheMach1neDK'
description '@TheMach1neDK | Politi afspærringstape'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@st_libs/init.lua',
    '@es_extended/imports.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'es_extended',
    'ox_lib',
    'ox_inventory',
    'st_libs',
}
