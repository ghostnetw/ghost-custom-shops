local tiendasRegistradas = {}
local lastTiendaCercana = nil
local tiendaTextUIActive = false
local puedeAbrirTienda = false
local createdZones = {}

-- Solo staff/admins pueden crear/editar tiendas
local function isAdmin()
    -- Puedes mejorar esto con exports o eventos si tienes un sistema de permisos en el cliente
    return LocalPlayer.state.isStaff or LocalPlayer.state.isAdmin or false
end

RegisterCommand("creartienda", function()
    if not isAdmin() then
        lib.notify({ title = "Permiso denegado", description = "Solo staff/admin puede crear tiendas.", type = "error" })
        return
    end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    abrirMenuInfoTienda(coords)
end)

function abrirMenuInfoTienda(coords)
    local input = lib.inputDialog('Información de la Tienda', {
        {type = 'input', label = 'Nombre de la tienda (ID)', placeholder = 'ej: armeria_paleto', required = true},
        {type = 'number', label = 'Slots del inventario', placeholder = 'ej: 50', required = true}
    })
    if not input then return end

    local shopName = input[1]
    local slots = tonumber(input[2])
    local items = {}

    while true do
        local itemInput = lib.inputDialog('Agregar producto a la tienda', {
            {type = 'input', label = 'Nombre del item (ej: agua)', required = true},
            {type = 'input', label = 'Label del item (ej: Agua)', required = true},
            {type = 'number', label = 'Cantidad', required = true},
            {type = 'number', label = 'Precio', required = true}
        })
        if not itemInput then break end
        table.insert(items, {
            name = itemInput[1],
            label = itemInput[2],
            amount = tonumber(itemInput[3]),
            price = tonumber(itemInput[4])
        })
        local continuar = lib.alertDialog({
            header = '¿Agregar otro producto?',
            content = '¿Quieres agregar otro producto a la tienda?',
            centered = true,
            cancel = true
        })
        if continuar == 'cancel' then break end
    end

    TriggerServerEvent("tienda:crearNuevaTienda", shopName, slots, coords, items)
end

RegisterCommand("gestiontiendas", function()
    if not isAdmin() then
        lib.notify({ title = "Permiso denegado", description = "Solo staff/admin puede gestionar tiendas.", type = "error" })
        return
    end
    TriggerServerEvent("tienda:solicitarTiendasGestion")
end)

RegisterNetEvent("tienda:abrirMenuGestionTiendas", function(tiendas)
    local opcionesTiendas = {}
    for _, tienda in ipairs(tiendas) do
        table.insert(opcionesTiendas, {
            title = tienda.name,
            description = "Slots: " .. tienda.slots .. " | Productos: " .. #tienda.items,
            onSelect = function()
                abrirMenuGestionProductos(tienda)
            end
        })
    end

    lib.registerContext({
        id = 'menu_gestion_tiendas',
        title = 'Gestión de Tiendas',
        options = opcionesTiendas
    })
    lib.showContext('menu_gestion_tiendas')
end)

function abrirMenuGestionProductos(tienda)
    local opcionesProductos = {}

    for idx, item in ipairs(tienda.items) do
        table.insert(opcionesProductos, {
            title = (item.label or item.name) .. " (" .. (item.amount or 1) .. ")",
            description = "Editar o eliminar | $" .. (item.price or 0),
            image = "nui://ox_inventory/web/images/" .. item.name .. ".png",
            onSelect = function()
                editarProductoTienda(tienda, idx)
            end
        })
    end

    table.insert(opcionesProductos, {
        title = "Agregar nuevo producto",
        icon = "plus",
        onSelect = function()
            agregarProductoTienda(tienda)
        end
    })

    table.insert(opcionesProductos, {
        title = "Guardar cambios",
        icon = "save",
        onSelect = function()
            TriggerServerEvent("tienda:guardarItemsGestion", tienda.name, tienda.items)
        end
    })

    lib.registerContext({
        id = 'menu_gestion_productos_' .. tienda.name,
        title = 'Productos de ' .. tienda.name,
        options = opcionesProductos
    })
    lib.showContext('menu_gestion_productos_' .. tienda.name)
end

function editarProductoTienda(tienda, idx)
    local item = tienda.items[idx]
    local input = lib.inputDialog('Editar producto', {
        {type = 'input', label = 'Nombre del item', default = item.name, required = true},
        {type = 'input', label = 'Label', default = item.label, required = true},
        {type = 'number', label = 'Cantidad', default = item.amount or 1, required = true},
        {type = 'number', label = 'Precio', default = item.price or 0, required = true}
    })
    if input then
        tienda.items[idx] = {
            name = input[1],
            label = input[2],
            amount = tonumber(input[3]),
            price = tonumber(input[4])
        }
        abrirMenuGestionProductos(tienda)
    else
        abrirMenuGestionProductos(tienda)
    end
end

function agregarProductoTienda(tienda)
    local input = lib.inputDialog('Agregar producto', {
        {type = 'input', label = 'Nombre del item', required = true},
        {type = 'input', label = 'Label', required = true},
        {type = 'number', label = 'Cantidad', required = true},
        {type = 'number', label = 'Precio', required = true}
    })
    if input then
        table.insert(tienda.items, {
            name = input[1],
            label = input[2],
            amount = tonumber(input[3]),
            price = tonumber(input[4])
        })
        abrirMenuGestionProductos(tienda)
    else
        abrirMenuGestionProductos(tienda)
    end
end

RegisterNetEvent("tienda:cargarTiendas", function(tiendas)
    tiendasRegistradas = tiendas
    setupQbTargetShops()
end)

function setupQbTargetShops()
    for _, zone in ipairs(createdZones) do
        exports['qb-target']:RemoveZone(zone)
    end
    createdZones = {}

    for _, tienda in pairs(tiendasRegistradas or {}) do
        local coords = tienda.coords
        if type(coords) == "table" then
            coords = vector3(coords.x, coords.y, coords.z)
        end

        local zoneName = "tienda_" .. tienda.name
        local tiendaName = tienda.name
        exports['qb-target']:AddCircleZone(zoneName, coords, 1.5, {
            name = zoneName,
            debugPoly = false,
        }, {
            options = {
                {
                    icon = "fas fa-store",
                    label = "Abrir tienda",
                    action = function()
                        TriggerServerEvent("tienda:abrirTienda", tiendaName)
                    end
                }
            },
            distance = 2.5
        })
        table.insert(createdZones, zoneName)
    end
end

CreateThread(function()
    while true do
        Wait(0)
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local tiendaCercana = nil
        for _, tienda in pairs(tiendasRegistradas or {}) do
            local tCoords = tienda.coords
            if type(tCoords) == "table" then
                tCoords = vector3(tCoords.x, tCoords.y, tCoords.z)
            end
            if #(coords - tCoords) < 2.5 then
                tiendaCercana = tienda
                break
            end
        end
        if tiendaCercana and (not lastTiendaCercana or lastTiendaCercana.name ~= tiendaCercana.name) then
            if lib and lib.showTextUI and not tiendaTextUIActive then
                lib.showTextUI('[E] Abrir tienda: ' .. tiendaCercana.name, {
                    position = 'top-center',
                    icon = 'store',
                    style = { backgroundColor = '#222E50', color = '#fff' }
                })
                tiendaTextUIActive = true
            end
            lastTiendaCercana = tiendaCercana
            puedeAbrirTienda = true
        elseif not tiendaCercana and lastTiendaCercana then
            if lib and lib.hideTextUI and tiendaTextUIActive then
                lib.hideTextUI()
                tiendaTextUIActive = false
            end
            lastTiendaCercana = nil
            puedeAbrirTienda = false
        end
        if puedeAbrirTienda and lastTiendaCercana and IsControlJustReleased(0, 38) then -- E
            TriggerServerEvent("tienda:abrirTienda", lastTiendaCercana.name)
            Wait(500)
        end
    end
end)

RegisterNetEvent("tienda:mostrarMenuTienda", function(tienda)
    local options = {}
    if not tienda.items or #tienda.items == 0 then
        table.insert(options, { title = "Sin productos", description = "Esta tienda no tiene productos aún.", icon = "ban" })
    else
        for _, item in ipairs(tienda.items) do
            table.insert(options, {
                title = item.label or item.name or "Item",
                description = "Cantidad: " .. (item.amount or 1) .. " | $" .. (item.price or 0),
                icon = "box",
                image = "nui://ox_inventory/web/images/" .. item.name .. ".png",
                onSelect = function()
                    local cantidad = lib.inputDialog('Comprar ' .. (item.label or item.name), {
                        {type = 'number', label = 'Cantidad a comprar', required = true, min = 1, max = item.amount or 1}
                    })
                    if cantidad and cantidad[1] and cantidad[1] > 0 then
                        TriggerServerEvent("tienda:comprarItem", tienda.name, item.name, cantidad[1], item.price)
                    end
                end
            })
        end
    end

    lib.registerContext({
        id = 'menu_tienda_' .. tienda.name,
        title = 'Tienda: ' .. tienda.name,
        options = options
    })
    lib.showContext('menu_tienda_' .. tienda.name)
end)
