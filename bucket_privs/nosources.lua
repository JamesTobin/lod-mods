minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if newnode.name == "default:lava_source" or newnode.name == "default:water_source" or newnode.name == "default:river_water_source" then
    	if not minetest.get_player_privs(placer:get_player_name()).spill then
    		minetest.chat_send_player(placer:get_player_name(),"Lava/Water sources cannot be placed without spill privs.", true)
    		minetest.remove_node(pos)
    		return itemstack
    	end
	end
end)



