-- Minetest 0.4 mod: bucket
-- See README.txt for licensing and other information.
 
 
--[[
        Argos' "spill" priv code has been added to buckets
        ~ LazyJ, 2015_03_05
--]]
 
minetest.register_alias("bucket", "bucket:bucket_empty")
minetest.register_alias("bucket_water", "bucket:bucket_water")
minetest.register_alias("bucket_lava", "bucket:bucket_lava")
 
minetest.register_privilege("spill", "Can empty buckets")
-- To deny singleplayer the spill privilege (for local testing):
--minetest.register_privilege("spill", {description = "Can empty buckets",give_to_singleplayer = false})
 
dofile(minetest.get_modpath("bucket_privs") .. "/nosources.lua")

minetest.register_craft({
        output = 'bucket:bucket_empty 1',
        recipe = {
                {'default:steel_ingot', '', 'default:steel_ingot'},
                {'', 'default:steel_ingot', ''},
        }
})
 
bucket = {}
bucket.liquids = {}
 
local function check_protection(pos, name, text)
        local protected = false
        if minetest.is_protected(pos, name) then
                protected = true
        else
                -- permafy check (wazuland2)
                local meta = minetest.env:get_meta(pos)
                local owner
                if meta then
                        owner = meta:get_string("owner")
                        if owner ~= name and owner ~= "" then
                                protected = true
                                if name ~= "" then
                                        minetest.chat_send_player(name, "(" .. pos.x .. "," .. pos.y .. "," .. pos.z .. ") is protected by " .. owner .. ".")
                                end
                        end
                end
        end
        if protected then
                minetest.log("action", (name ~= "" and name or "A mod")
                        .. " tried to " .. text
                        .. " at protected position "
                        .. minetest.pos_to_string(pos)
                        .. " with a bucket")
                minetest.record_protection_violation(pos, name)
                return true
        end
        return false
end
 
-- Register a new liquid
--   source = name of the source node
--   flowing = name of the flowing node
--   itemname = name of the new bucket item (or nil if liquid is not takeable)
--   inventory_image = texture of the new bucket item (ignored if itemname == nil)
-- This function can be called from any mod (that depends on bucket).
function bucket.register_liquid(source, flowing, itemname, inventory_image, name)
        bucket.liquids[source] = {
                source = source,
                flowing = flowing,
                itemname = itemname,
        }
        bucket.liquids[flowing] = bucket.liquids[source]
 
        if itemname ~= nil then
                minetest.register_craftitem(":"..itemname, {
                        description = name,
                        inventory_image = inventory_image,
                        stack_max = 1,
                        liquids_pointable = true,
                        on_place = function(itemstack, user, pointed_thing)
                                -- Must be pointing to node
                                if pointed_thing.type ~= "node" then
                                        return
                                end
 
                                local can_spill = minetest.check_player_privs(user.get_player_name(user), {spill=true})
 
                                local node = minetest.get_node_or_nil(pointed_thing.under)
                                local ndef
                                if node then
                                        ndef = minetest.registered_nodes[node.name]
                                end
                                -- Call on_rightclick if the pointed node defines it
                                if ndef and ndef.on_rightclick and
                                   user and not user:get_player_control().sneak then
                                        return ndef.on_rightclick(
                                                pointed_thing.under,
                                                node, user,
                                                itemstack) or itemstack
                                end
 
                                local place_liquid = function(pos, node, source, flowing)
                                        if check_protection(pos,
                                                        user and user:get_player_name() or "",
                                                        "place "..source) then
                                                return
                                        end
                                        minetest.add_node(pos, {name=source})
                                end
 
                                -- Check if pointing to a buildable node
                                local pos = minetest.get_pointed_thing_position(pointed_thing, pointed_thing.above)
                                        local spill_xyz = " at " .. pos.x .. "," .. pos.y .. "," .. pos.z
                                        if can_spill then
                                if ndef and ndef.buildable_to then
                                        -- buildable; replace the node
                                        minetest.log("action", user.get_player_name(user) .. " spills " .. source .. " replacing " .. ndef.name .. spill_xyz)
                                        place_liquid(pointed_thing.under, node,
                                                        source, flowing)
                                else
                                        -- not buildable to; place the liquid above
                                        -- check if the node above can be replaced
                                        local node = minetest.get_node_or_nil(pointed_thing.above)
                                        if node and minetest.registered_nodes[node.name].buildable_to then
                                                minetest.log("action", user.get_player_name(user) .. " spills " .. source .. " replacing " .. node.name .. spill_xyz)
                                                place_liquid(pointed_thing.above,
                                                                node, source,
                                                                flowing)
                                        else
                                                -- do not remove the bucket with the liquid
                                                return
                                        end
                                end
                                else
                                        -- no spill priv. Allow emptying to origin liquid.
                                        if not ndef or ndef.name ~= source then
                                                minetest.log("action", user.get_player_name(user) .. " is not allowed to spill " .. source .. spill_xyz)
                                                minetest.chat_send_player(user.get_player_name(user),"DENIED! You don't have spill privs.")
                                                return
                                        else
                                                minetest.log("action", user.get_player_name(user) .. " empties bucket of " .. source .. spill_xyz)
                                                minetest.chat_send_player(user.get_player_name(user),"DENIED! You don't have spill privs.")
                                        end
                                end
                                return {name="bucket:bucket_empty"}
                        end
                })
        end
end
 
minetest.register_craftitem(":bucket:bucket_empty", {
    description = "Empty Bucket",
    inventory_image = "bucket.png",
    stack_max = 99,
    liquids_pointable = true,
    on_use = function(itemstack, user, pointed_thing)
        -- Must be pointing to node
        if pointed_thing.type ~= "node" then
            return
        end
        -- Check if pointing to a liquid source
        local node = minetest.get_node(pointed_thing.under)
        local liquiddef = bucket.liquids[node.name]
        local item_count = user:get_wielded_item():get_count()
 
        if liquiddef ~= nil
        and liquiddef.itemname ~= nil
        and node.name == liquiddef.source then
            if check_protection(pointed_thing.under,
                    user:get_player_name(),
                    "take ".. node.name) then
                return
            end
 
            -- default set to return filled bucket
            local giving_back = liquiddef.itemname
 
            -- check if holding more than 1 empty bucket
            if item_count > 1 then
 
                -- if space in inventory add filled bucked, otherwise drop as item
                local inv = user:get_inventory()
                if inv:room_for_item("main", {name=liquiddef.itemname}) then
                    inv:add_item("main", liquiddef.itemname)
                else
                    local pos = user:getpos()
                    pos.y = math.floor(pos.y + 20.5)
                    core.add_item(pos, liquiddef.itemname)
                end
 
                -- set to return empty buckets minus 1
                giving_back = "bucket:bucket_empty "..tostring(item_count-1)
 
            end
 
            minetest.add_node(pointed_thing.under, {name="air"})
 
            return ItemStack(giving_back)
        end
    end,
})
 
bucket.register_liquid(
	"default:water_source",
	"default:water_flowing",
	"bucket:bucket_water",
	"bucket_water.png",
	"Water Bucket",
	{water_bucket = 1}
)

bucket.register_liquid(
	"default:river_water_source",
	"default:river_water_flowing",
	"bucket:bucket_river_water",
	"bucket_river_water.png",
	"River Water Bucket",
	{water_bucket = 1}
)
 
bucket.register_liquid(
        "default:lava_source",
        "default:lava_flowing",
        "bucket:bucket_lava",
        "bucket_lava.png",
        "Lava Bucket"
)
 
minetest.register_craft({
        type = "fuel",
        recipe = "bucket:bucket_lava",
        burntime = 60,
        replacements = {{"bucket:bucket_lava", "bucket:bucket_empty"}},

    })

