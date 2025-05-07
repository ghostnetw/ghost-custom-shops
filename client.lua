local creandoTienda = false
local tiendasRegistradas = {}
local tiendaTextUIActive = false
local tiendaTextUIZone = nil
local lastTiendaCercana = nil
local puedeAbrirTienda = false
local shopBlips = {}

RegisterCommand("creartienda", function()
    if creandoTienda then return end
    creandoTienda = true
    if lib and lib.showTextUI then
        lib.showTextUI('[E] Colocar tienda aquí', {
            position = 'top-center',
            icon = 'store',
            style = { backgroundColor = '#222E50', color = '#fff' }
        })
    end
    TriggerEvent('chat:addMessage', { args = { 'Sistema de Tiendas', 'Camina al lugar deseado y presiona [E] para colocar la tienda.' } })
    CreateThread(function()
        while creandoTienda do
            Wait(0)
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.6, 0, 120, 255, 200, false, false, 2, false, nil, nil, false)
            if IsControlJustReleased(0, 38) then -- E
                creandoTienda = false
                if lib and lib.hideTextUI then lib.hideTextUI() end
                abrirMenuInfoTienda(coords)
            end
        end
        if lib and lib.hideTextUI then lib.hideTextUI() end
    end)
end)

function abrirMenuInfoTienda(coords)
    -- Primer input: nombre y slots
    local input = lib.inputDialog('Información de la Tienda', {
        {type = 'input', label = 'Nombre de la tienda (ID)', placeholder = 'ej: armeria_paleto', required = true},
        {type = 'number', label = 'Slots del inventario', placeholder = 'ej: 50', required = true}
    })
    if not input then return end

    local shopName = input[1]
    local slots = tonumber(input[2])
    local items = {}

    -- Segundo input: agregar productos
    while true do
        local itemInput = lib.inputDialog('Agregar producto a la tienda', {
            {type = 'input', label = 'Nombre del item (ej: agua)', required = true},
            {type = 'input', label = 'Label del item (ej: Agua)', required = true},
            {type = 'number', label = 'Cantidad', required = true}
        })
        if not itemInput then break end
        table.insert(items, {
            name = itemInput[1],
            label = itemInput[2],
            amount = tonumber(itemInput[3])
        })
        -- Preguntar si quiere agregar otro producto
        local continuar = lib.alertDialog({
            header = '¿Agregar otro producto?',
            content = '¿Quieres agregar otro producto a la tienda?',
            centered = true,
            cancel = true
        })
        if continuar == 'cancel' then break end
    end

    -- Crear la tienda y guardar los productos
    TriggerServerEvent("tienda:crearNuevaTienda", shopName, slots, coords, items)
end

RegisterNetEvent("tienda:cargarTiendas", function(tiendas)
    tiendasRegistradas = tiendas
    setupQbTargetShops()

    -- Remove old blips
    for _, blip in ipairs(shopBlips) do
        RemoveBlip(blip)
    end
    shopBlips = {}

    -- Add new blips for each shop
    for _, tienda in ipairs(tiendasRegistradas or {}) do
        local coords = tienda.coords
        if type(coords) == "table" then
            coords = vector3(coords.x, coords.y, coords.z)
        end
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, 52) -- 52 = Store icon, change if you want a different icon
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.8)
        SetBlipColour(blip, 2) -- 2 = Green, change if you want a different color
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(tienda.name or "Tienda")
        EndTextCommandSetBlipName(blip)
        table.insert(shopBlips, blip)
    end
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- QBCore Target integration
local createdZones = {}

function mostrarTextUITienda(tienda)
    if lib and lib.showTextUI and not tiendaTextUIActive then
        lib.showTextUI('[E] Abrir tienda: ' .. tienda.name, {
            position = 'top-center',
            icon = 'store',
            style = { backgroundColor = '#222E50', color = '#fff' }
        })
        tiendaTextUIActive = true
    end
end

function ocultarTextUITienda()
    if lib and lib.hideTextUI and tiendaTextUIActive then
        lib.hideTextUI()
        tiendaTextUIActive = false
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
        -- Detectar pulsación de E para abrir tienda
        if puedeAbrirTienda and lastTiendaCercana and IsControlJustReleased(0, 38) then -- E
            TriggerServerEvent("tienda:abrirTienda", lastTiendaCercana.name)
            Wait(500) -- Evita doble apertura
        end
    end
end)

function setupQbTargetShops()
    -- Elimina zonas anteriores
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
                        print("[DEBUG] Intentando abrir tienda desde target:", tiendaName)
                        TriggerServerEvent("tienda:abrirTienda", tiendaName)
                    end
                }
            },
            distance = 2.5
        })
        table.insert(createdZones, zoneName)
    end
end

-- Si quieres mantener el marker y texto 3D para debug, puedes dejar el bucle, pero ya no es necesario con qb-target.

RegisterNetEvent("tienda:abrirEditorItems", function(shopName)
    if lib and lib.showTextUI then
        lib.showTextUI('Edita los ítems de la tienda: ' .. shopName .. '\nUsa el comando /guardaritems cuando termines.', {
            position = 'top-center',
            icon = 'box',
            style = { backgroundColor = '#222E50', color = '#fff' }
        })
        SetTimeout(7000, function()
            if lib and lib.hideTextUI then lib.hideTextUI() end
        end)
    else
        TriggerEvent('chat:addMessage', { args = { 'Sistema de Tiendas', 'Edita los ítems de la tienda: ' .. shopName } })
    end
end)

RegisterNetEvent("tienda:mostrarMenuTienda", function(tienda)
    print("[DEBUG] Recibido tienda para mostrar menú:", json.encode(tienda))
    local options = {}

    if not tienda.items or #tienda.items == 0 then
        table.insert(options, { title = "Sin productos", description = "Esta tienda no tiene productos aún.", icon = "ban" })
    else
        for _, item in ipairs(tienda.items) do
            table.insert(options, {
                title = item.label or item.name or "Item",
                description = "Cantidad: " .. (item.amount or 1),
                icon = "box",
                image = "nui://ox_inventory/web/images/" .. item.name .. ".png",
                onSelect = function()
                    local cantidad = lib.inputDialog('Comprar ' .. (item.label or item.name), {
                        {type = 'number', label = 'Cantidad a comprar', required = true, min = 1, max = item.amount or 1}
                    })
                    if cantidad and cantidad[1] and cantidad[1] > 0 then
                        TriggerServerEvent("tienda:comprarItem", tienda.name, item.name, cantidad[1])
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

CreateThread(function()
    Wait(2000) -- Espera a que el jugador esté completamente cargado
    TriggerServerEvent("tienda:solicitarTiendas")
end)

RegisterCommand("gestiontiendas", function()
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
            description = "Editar o eliminar",
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
        {type = 'number', label = 'Cantidad', default = item.amount or 1, required = true}
    })
    if input then
        tienda.items[idx] = {
            name = input[1],
            label = input[2],
            amount = tonumber(input[3])
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
        {type = 'number', label = 'Cantidad', required = true}
    })
    if input then
        table.insert(tienda.items, {
            name = input[1],
            label = input[2],
            amount = tonumber(input[3])
        })
        abrirMenuGestionProductos(tienda)
    else
        abrirMenuGestionProductos(tienda)
    end
end

