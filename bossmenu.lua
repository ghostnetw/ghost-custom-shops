----------------server side-------------------

local QBCore = exports['qb-core']:GetCoreObject()

-- Abrir el boss menu (solo para el dueño)
RegisterNetEvent("tienda:abrirBossMenu", function()
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local identifier = xPlayer.PlayerData.citizenid

    exports.oxmysql:execute('SELECT * FROM tiendas WHERE owner = ?', {identifier}, function(result)
        if result and #result > 0 then
            local tienda = result[1]
            TriggerClientEvent("tienda:mostrarBossMenu", src, {
                name = tienda.name,
                balance = tienda.balance or 0
            })
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Boss Menu',
                description = 'No eres dueño de ninguna tienda.',
                type = 'error'
            })
        end
    end)
end)

-- Retirar dinero del balance de la tienda
RegisterNetEvent("tienda:retirarDineroTienda", function(shopName, cantidad)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local identifier = xPlayer.PlayerData.citizenid

    exports.oxmysql:execute('SELECT * FROM tiendas WHERE name = ? AND owner = ?', {shopName, identifier}, function(result)
        if result and result[1] then
            local tienda = result[1]
            cantidad = tonumber(cantidad)
            local balance = tonumber(tienda.balance) or 0
            if cantidad > 0 and cantidad <= balance then
                exports.oxmysql:execute('UPDATE tiendas SET balance = balance - ? WHERE name = ?', {cantidad, shopName})
                xPlayer.Functions.AddMoney('bank', cantidad)
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Boss Menu',
                    description = ('Retiraste $%s de la tienda %s'):format(cantidad, shopName),
                    type = 'success'
                })
            else
                TriggerClientEvent('ox_lib:notify', src, {
                    title = 'Boss Menu',
                    description = 'Cantidad inválida o insuficiente.',
                    type = 'error'
                })
            end
        else
            TriggerClientEvent('ox_lib:notify', src, {
                title = 'Boss Menu',
                description = 'No tienes acceso a esta tienda.',
                type = 'error'
            })
        end
    end)
end)

----------------client side-------------------

RegisterCommand("bossmenu", function()
    TriggerServerEvent("tienda:abrirBossMenu")
end)

RegisterNetEvent("tienda:mostrarBossMenu", function(tienda)
    local input = lib.inputDialog('Boss Menu de ' .. tienda.name, {
        {type = 'number', label = 'Cantidad a retirar', required = true, min = 1, max = tienda.balance}
    })
    if input and input[1] then
        TriggerServerEvent("tienda:retirarDineroTienda", tienda.name, input[1])
    end
end)