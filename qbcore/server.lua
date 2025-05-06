local QBCore = exports['qb-core']:GetCoreObject()

-- Utilidad para logs
local function log(msg)
    print("[TIENDAS QBCORE] " .. msg)
end

-- Permite solo a staff/admins crear/editar tiendas
local function isAdmin(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return false end
    -- Puedes cambiar esto por tu sistema de permisos
    return Player.PlayerData.permission == "admin" or Player.PlayerData.permission == "god" or IsPlayerAceAllowed(src, "command")
end

RegisterNetEvent("tienda:crearNuevaTienda", function(shopName, slots, coords, items)
    local src = source
    if not isAdmin(src) then
        log(("Intento NO AUTORIZADO de crear tienda por %s"):format(src))
        return
    end
    exports.oxmysql:execute('INSERT INTO tiendas (name, coords_x, coords_y, coords_z, slots, items) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE coords_x=VALUES(coords_x), coords_y=VALUES(coords_y), coords_z=VALUES(coords_z), slots=VALUES(slots), items=VALUES(items)', {
        shopName, coords.x, coords.y, coords.z, slots, json.encode(items or {})
    }, function()
        log(("Tienda creada/actualizada: %s por %s"):format(shopName, src))
        cargarYEnviarTiendas()
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Tienda creada',
            description = 'La tienda fue creada correctamente.',
            type = 'success'
        })
    end)
end)

RegisterNetEvent("tienda:guardarItemsGestion", function(shopName, items)
    local src = source
    if not isAdmin(src) then
        log(("Intento NO AUTORIZADO de editar tienda por %s"):format(src))
        return
    end
    exports.oxmysql:execute('UPDATE tiendas SET items = ? WHERE name = ?', {
        json.encode(items), shopName
    }, function()
        log(("Productos actualizados en tienda %s por %s"):format(shopName, src))
        cargarYEnviarTiendas()
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Gestión de Tienda',
            description = 'Productos actualizados correctamente.',
            type = 'success'
        })
    end)
end)

RegisterNetEvent("tienda:abrirTienda", function(shopName)
    local src = source
    exports.oxmysql:execute('SELECT * FROM tiendas WHERE name = ?', {shopName}, function(result)
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

RegisterNetEvent("tienda:comprarItem", function(shopName, itemName, cantidad, precio)
    local src = source
    cantidad = tonumber(cantidad) or 1
    precio = tonumber(precio) or 0
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local total = cantidad * precio
    if Player.PlayerData.money.cash < total then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Compra',
            description = 'No tienes suficiente dinero.',
            type = 'error'
        })
        return
    end

    -- Quitar dinero
    Player.Functions.RemoveMoney('cash', total, "Compra en tienda: " .. shopName)
    -- Dar el ítem
    exports.ox_inventory:AddItem(src, itemName, cantidad)
    log(("Compra: %s x%d por $%d en %s (player %s)"):format(itemName, cantidad, total, shopName, src))

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Compra',
        description = ('Compraste %sx %s por $%d en %s'):format(cantidad, itemName, total, shopName),
        type = 'success'
    })
end)

RegisterNetEvent("tienda:solicitarTiendas", function()
    local src = source
    cargarYEnviarTiendas(src)
end)

RegisterNetEvent("tienda:solicitarTiendasGestion", function()
    local src = source
    if not isAdmin(src) then return end
    exports.oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
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

function cargarYEnviarTiendas(target)
    exports.oxmysql:execute('SELECT * FROM tiendas', {}, function(result)
        local tiendas = {}
        for _, row in ipairs(result) do
            table.insert(tiendas, {
                name = row.name,
                coords = { x = row.coords_x, y = row.coords_y, z = row.coords_z },
                slots = row.slots,
                items = json.decode(row.items or '{}')
            })
        end
        if target then
            TriggerClientEvent("tienda:cargarTiendas", target, tiendas)
        else
            TriggerClientEvent("tienda:cargarTiendas", -1, tiendas)
        end
    end)
end
