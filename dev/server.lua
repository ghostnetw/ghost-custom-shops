local oxmysql = exports['oxmysql']

-- Ruta relativa a la carpeta DEV
local configPath = "./config.lua"

local function guardarTiendasEnConfig()
    oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
        local tiendas = {}
        for _, row in ipairs(result) do
            table.insert(tiendas, {
                name = row.name,
                coords = { x = row.coords_x, y = row.coords_y, z = row.coords_z },
                slots = row.slots,
                items = json.decode(row.items or '{}')
            })
        end

        local file = io.open(configPath, "w+")
        file:write("Config = {}\n")
        file:write("Config.Tiendas = ")
        file:write(json.encode(tiendas, { indent = true }))
        file:write("\n")
        file:close()
        print("[DEBUG] Tiendas guardadas en config.lua")
    end)
end

RegisterNetEvent("tienda:crearNuevaTienda", function(shopName, slots, coords, items)
    local src = source
    print("[DEBUG] Recibido crearNuevaTienda:", shopName, slots, coords and coords.x, coords and coords.y, coords and coords.z)
    oxmysql:execute('INSERT INTO tiendas (name, coords_x, coords_y, coords_z, slots, items) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE coords_x=VALUES(coords_x), coords_y=VALUES(coords_y), coords_z=VALUES(coords_z), slots=VALUES(slots), items=VALUES(items)', {
        shopName, coords.x, coords.y, coords.z, slots, json.encode(items or {})
    }, function(result)
        print("[DEBUG] Resultado del insert tienda:", json.encode(result))
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Tienda creada',
            description = 'La tienda fue creada correctamente.',
            type = 'success'
        })
        cargarYEnviarTiendas()
        guardarTiendasEnConfig()
    end)
end)

RegisterNetEvent("tienda:guardarItems", function(shopName, items)
    local src = source
    oxmysql:execute('UPDATE tiendas SET items = ? WHERE name = ?', {
        json.encode(items), shopName
    }, function()
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Items guardados',
            description = 'La tienda ya está lista.',
            type = 'success'
        })
        cargarYEnviarTiendas()
        guardarTiendasEnConfig()
    end)
end)

RegisterNetEvent("tienda:abrirTienda", function(shopName)
    local src = source
    oxmysql:execute('SELECT * FROM tiendas WHERE name = ?', {shopName}, function(result)
        if result and result[1] then
            local tienda = result[1]
            TriggerClientEvent("tienda:mostrarMenuTienda", src, {
                name = tienda.name,
                slots = tienda.slots,
                items = json.decode(tienda.items or '{}')
            })
        end
    end)
end)

RegisterNetEvent("tienda:comprarItem", function(shopName, itemName, cantidad)
    local src = source
    cantidad = tonumber(cantidad) or 1
    print(("[DEBUG] Compra solicitada: tienda=%s, item=%s, cantidad=%s"):format(shopName, itemName, cantidad))

    exports.ox_inventory:AddItem(src, itemName, cantidad)

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Compra',
        description = ('Compraste %sx %s en %s'):format(cantidad, itemName, shopName),
        type = 'success'
    })
end)

RegisterNetEvent("tienda:solicitarTiendas", function()
    local src = source
    cargarYEnviarTiendas(src)
end)

RegisterNetEvent("tienda:solicitarTiendasGestion", function()
    local src = source
    oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
        local tiendas = {}
        for _, row in ipairs(result) do
            table.insert(tiendas, {
                name = row.name,
                coords = { x = row.coords_x, y = row.coords_y, z = row.coords_z },
                slots = row.slots,
                items = json.decode(row.items or '{}')
            })
        end
        TriggerClientEvent("tienda:abrirMenuGestionTiendas", src, tiendas)
    end)
end)

RegisterNetEvent("tienda:guardarItemsGestion", function(shopName, items)
    local src = source
    oxmysql:execute('UPDATE tiendas SET items = ? WHERE name = ?', {
        json.encode(items), shopName
    }, function()
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Gestión de Tienda',
            description = 'Productos actualizados correctamente.',
            type = 'success'
        })
        cargarYEnviarTiendas()
        guardarTiendasEnConfig()
    end)
end)

function cargarYEnviarTiendas(target)
    oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
        local tiendas = {}
        if result and #result > 0 then
            for _, row in ipairs(result) do
                table.insert(tiendas, {
                    name = row.name,
                    coords = { x = row.coords_x, y = row.coords_y, z = row.coords_z },
                    slots = row.slots,
                    items = json.decode(row.items or '{}')
                })
            end
        else
            -- Si no hay tiendas en la base de datos, intenta cargar desde config.lua
            local config = loadfile(configPath)()
            if config and config.Tiendas then
                tiendas = config.Tiendas
                print("[DEBUG] Tiendas cargadas desde config.lua")
            end
        end
        if target then
            TriggerClientEvent("tienda:cargarTiendas", target, tiendas)
        else
            TriggerClientEvent("tienda:cargarTiendas", -1, tiendas)
        end
    end)
end

RegisterCommand("pruebaconfig", function(source, args, raw)
    local file, err = io.open("./config.lua", "w+")
    if not file then
        print("[PRUEBA CONFIG] Error al abrir config.lua para escribir: " .. tostring(err))
        return
    end
    file:write("-- Prueba de escritura exitosa\n")
    file:close()
    print("[PRUEBA CONFIG] Escritura en config.lua completada correctamente.")
end, true)
