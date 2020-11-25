minetest.override_item("default:lava_source", {
	on_construct = function(pos)
		if pos.y >= 0 then
			minetest.env:remove_node(pos)
		end
	end
})
