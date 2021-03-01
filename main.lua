ESX = nil
local Weapons = {}
local Loaded = false
local spawned_object = {}

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end

	while not Loaded do
		Citizen.Wait(500)
	end

	while true do
		local playerPed = PlayerPedId()
		Citizen.Wait(1000) -- refresh time

		for i=1, #Config.RealWeapons, 1 do
			local weaponHash = GetHashKey(Config.RealWeapons[i].name)

			if HasPedGotWeapon(playerPed, weaponHash, false) then
				local onPlayer = false

				for weaponName, entity in pairs(Weapons) do
					if weaponName == Config.RealWeapons[i].name then
						onPlayer = true
						break
					end
				end

				if not onPlayer and weaponHash ~= GetSelectedPedWeapon(playerPed) then
					SetGear(Config.RealWeapons[i].name)
				elseif onPlayer and weaponHash == GetSelectedPedWeapon(playerPed) then
					RemoveGear(Config.RealWeapons[i].name)
				end
			end
		end
	end
end)

AddEventHandler('skinchanger:modelLoaded', function()
	SetGears()
	fixchar()
	Loaded = true

end)

RegisterNetEvent('esx:removeWeapon')
AddEventHandler('esx:removeWeapon', function(weaponName)
	RemoveGear(weaponName)

end)

-- Remove only one weapon that's on the ped
function RemoveGear(weapon)
	local _Weapons = {}

	for weaponName, entity in pairs(Weapons) do
		if weaponName ~= weapon then
			_Weapons[weaponName] = entity
		else
			ESX.Game.DeleteObject(entity)

			for i=1, #spawned_object do
				if spawned_object[i] == GetHashKey(weapon) then
					table.remove(spawned_object, i) -- remove object from spawned object list
					break
				end
			end
		end
	end

	Weapons = _Weapons
end

-- Remove all weapons that are on the ped
function RemoveGears()
	for weaponName, entity in pairs(Weapons) do
		ESX.Game.DeleteObject(entity)
	end

	spawned_object = {} -- make sure reinitialize list
	Weapons = {}
end

AddEventHandler('onResourceStop', function(resource)
	if resource == GetCurrentResourceName() then
		for name, entity in pairs(Weapons) do
			ESX.Game.DeleteObject(entity.handle)
			Weapons[name] = nil
		end
	end
end)

-- Add one weapon on the ped
function SetGear(weapon)
	-- dont need to process anything if unarmed
	if weapon ~= 'WEAPON_UNARMED' then
		local bone       = nil
		local boneX      = 0.0
		local boneY      = 0.0
		local boneZ      = 0.0
		local boneXRot   = 0.0
		local boneYRot   = 0.0
		local boneZRot   = 0.0
		local playerPed  = PlayerPedId()
		local model      = nil
		local already_spawned = false

		for i=1, #Config.RealWeapons, 1 do
			if Config.RealWeapons[i].name == weapon then
				bone     = Config.RealWeapons[i].bone
				boneX    = Config.RealWeapons[i].x
				boneY    = Config.RealWeapons[i].y
				boneZ    = Config.RealWeapons[i].z
				boneXRot = Config.RealWeapons[i].xRot
				boneYRot = Config.RealWeapons[i].yRot
				boneZRot = Config.RealWeapons[i].zRot
				model    = Config.RealWeapons[i].model
				break
			end
		end

		-- if spawned object already attached, mark already_spawned
		for i=1, #spawned_object do
			if spawned_object[i] == GetHashKey(weapon) then
				already_spawned = true
				break
			end
		end

		-- if object already spawned (attached) dont need to spawnobject (HIGH CPU USAGE)
		if not already_spawned then
			local synced = false
			ESX.Game.SpawnObject(model, {
				x = x,
				y = y,
				z = z
			}, function(object)
				local boneIndex = GetPedBoneIndex(playerPed, bone)
				local bonePos 	= GetWorldPositionOfEntityBone(playerPed, boneIndex)
				AttachEntityToEntity(object, playerPed, boneIndex, boneX, boneY, boneZ, boneXRot, boneYRot, boneZRot, false, false, false, false, 2, true)
				Weapons[weapon] = object

				-- list the spawned object to make sure to not reattached same object
				table.insert(spawned_object, GetHashKey(weapon))
			end)
		end
	end
end

-- Add all the weapons in the xPlayer's loadout
-- on the ped
function SetGears()
	local bone       = nil
	local boneX      = 0.0
	local boneY      = 0.0
	local boneZ      = 0.0
	local boneXRot   = 0.0
	local boneYRot   = 0.0
	local boneZRot   = 0.0
	local playerPed  = PlayerPedId()
	local model      = nil
	local playerData = ESX.GetPlayerData()
	local weapon 	 = nil

	spawned_object = {} -- make sure reinitialize list

	for i=1, #playerData.loadout, 1 do
		for j=1, #Config.RealWeapons, 1 do
			if Config.RealWeapons[j].name == playerData.loadout[i].name then
				bone     = Config.RealWeapons[j].bone
				boneX    = Config.RealWeapons[j].x
				boneY    = Config.RealWeapons[j].y
				boneZ    = Config.RealWeapons[j].z
				boneXRot = Config.RealWeapons[j].xRot
				boneYRot = Config.RealWeapons[j].yRot
				boneZRot = Config.RealWeapons[j].zRot
				model    = Config.RealWeapons[j].model
				weapon   = Config.RealWeapons[j].name
				break
			end
		end

		local _wait = true

		ESX.Game.SpawnObject(model, {
			x = x,
			y = y,
			z = z
		}, function(object)
			local boneIndex = GetPedBoneIndex(playerPed, bone)
			local bonePos 	= GetWorldPositionOfEntityBone(playerPed, boneIndex)

			AttachEntityToEntity(object, playerPed, boneIndex, boneX, boneY, boneZ, boneXRot, boneYRot, boneZRot, false, false, false, false, 2, true)
			Weapons[weapon] = object
			_wait = false
		end)

		-- list the spawned object to make sure to not reattached same object
		table.insert(spawned_object, GetHashKey(weapon))
		-- wait for async task
		while _wait do
			Citizen.Wait(10)
		end
	end

end

-- register /fixchar command to clear not owned weapon
RegisterCommand('fixchar', function(source)
	fixchar()
end)

function fixchar()
	local position = GetEntityCoords(GetPlayerPed(-1), false)
	Loaded = true

	for i=1, #Config.RealWeapons do
		local object = GetClosestObjectOfType(position.x, position.y, position.z, 2.0, GetHashKey(Config.RealWeapons[i].model), false, false, false)
		if object ~= 0 then
			-- call RemoveGear function to use "spawned_object = {}" on that function, u can skip this.
			RemoveGear(Config.RealWeapons[i].name)
			-- re-delete object few times, coz sometimes object still available
			--(5 is just small number, sometimes DeleteObject still not work, re /fixhar until everything looks okay)
			for x=1, 5 do
				DeleteObject(object)
			end
		end
	end

	-- make sure to re-attach all owned weapon
	SetGears()
end