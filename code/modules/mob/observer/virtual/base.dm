var/global/list/all_virtual_listeners = list()

/mob/observer/virtual
	icon = 'icons/mob/virtual.dmi'
	invisibility = INVISIBILITY_SYSTEM
	see_in_dark = SEE_IN_DARK_DEFAULT
	see_invisible = SEE_INVISIBLE_LIVING
	sight = SEE_SELF

	virtual_mob = null
	z_flags = ZMM_IGNORE

	var/atom/movable/host
	var/host_type = /atom/movable
	var/abilities = VIRTUAL_ABILITY_HEAR|VIRTUAL_ABILITY_SEE
	var/list/broadcast_methods

	var/static/list/overlay_icons

/mob/observer/virtual/Initialize(mapload, atom/movable/host)
	. = ..()

	if(!istype(host, host_type))
		CRASH("Received an unexpected host type. Expected [host_type], was [log_info_line(host)].")
	src.host = host
	GLOB.moved_event.register(host, src, TYPE_PROC_REF(/atom/movable, move_to_turf_or_null))

	all_virtual_listeners += src

	update_icon()

	STOP_PROCESSING_MOB(src)

/mob/observer/virtual/Destroy()
	GLOB.moved_event.unregister(host, src, TYPE_PROC_REF(/atom/movable, move_to_turf_or_null))
	all_virtual_listeners -= src
	host = null
	return ..()

/mob/observer/virtual/on_update_icon()
	if(!overlay_icons)
		overlay_icons = list()
		for(var/i_state in icon_states(icon))
			overlay_icons[i_state] = image(icon = icon, icon_state = i_state)
	ClearOverlays()

	if(abilities & VIRTUAL_ABILITY_HEAR)
		AddOverlays(overlay_icons["hear"])
	if(abilities & VIRTUAL_ABILITY_SEE)
		AddOverlays(overlay_icons["see"])

/***********************
* Virtual Mob Creation *
***********************/
/atom/movable/var/mob/observer/virtual/virtual_mob

/atom/movable/Initialize()
	. = ..()
	if(shall_have_virtual_mob())
		virtual_mob = new virtual_mob(get_turf(src), src)

/atom/movable/proc/shall_have_virtual_mob()
	return ispath(initial(virtual_mob))
