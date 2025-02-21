#define DEFAULT_PRESSURE_DELTA 10000

#define EXTERNAL_PRESSURE_BOUND ONE_ATMOSPHERE
#define INTERNAL_PRESSURE_BOUND 0
#define PRESSURE_CHECKS 1

#define PRESSURE_CHECK_EXTERNAL 1
#define PRESSURE_CHECK_INTERNAL 2

/obj/machinery/atmospherics/unary/vent_pump
	icon = 'icons/atmos/vent_pump.dmi'
	icon_state = "map_vent"

	name = "Air Vent"
	desc = "Has a valve and pump attached to it."
	use_power = POWER_USE_OFF
	idle_power_usage = 150		//internal circuitry, friction losses and stuff
	power_rating = 30000			// 30000 W ~ 40 HP

	connect_types = CONNECT_TYPE_REGULAR|CONNECT_TYPE_SUPPLY|CONNECT_TYPE_FUEL //connects to regular, supply pipes, and fuel pipes
	level = ATOM_LEVEL_UNDER_TILE
	identifier = "AVP"

	var/hibernate = 0 //Do we even process?
	var/pump_direction = 1 //0 = siphoning, 1 = releasing

	var/external_pressure_bound = EXTERNAL_PRESSURE_BOUND
	var/internal_pressure_bound = INTERNAL_PRESSURE_BOUND

	var/pressure_checks = PRESSURE_CHECKS
	//1: Do not pass external_pressure_bound
	//2: Do not pass internal_pressure_bound
	//3: Do not pass either

	// Used when handling incoming radio signals requesting default settings
	var/external_pressure_bound_default = EXTERNAL_PRESSURE_BOUND
	var/internal_pressure_bound_default = INTERNAL_PRESSURE_BOUND
	var/pressure_checks_default = PRESSURE_CHECKS

	var/welded = 0 // Added for aliens -- TLE

	var/controlled = TRUE  //if we should register with an air alarm on spawn
	build_icon_state = "uvent"

	uncreated_component_parts = list(
		/obj/item/stock_parts/power/apc,
		/obj/item/stock_parts/radio/receiver,
		/obj/item/stock_parts/radio/transmitter/on_event,
	)
	public_variables = list(
		/singleton/public_access/public_variable/input_toggle,
		/singleton/public_access/public_variable/area_uid,
		/singleton/public_access/public_variable/identifier,
		/singleton/public_access/public_variable/use_power,
		/singleton/public_access/public_variable/pump_dir,
		/singleton/public_access/public_variable/pump_checks,
		/singleton/public_access/public_variable/pressure_bound,
		/singleton/public_access/public_variable/pressure_bound/external,
		/singleton/public_access/public_variable/power_draw,
		/singleton/public_access/public_variable/flow_rate,
		/singleton/public_access/public_variable/name
	)
	public_methods = list(
		/singleton/public_access/public_method/toggle_power,
		/singleton/public_access/public_method/purge_pump,
		/singleton/public_access/public_method/refresh
	)
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump = 1
	)

	frame_type = /obj/item/pipe
	construct_state = /singleton/machine_construction/default/item_chassis
	base_type = /obj/machinery/atmospherics/unary/vent_pump

/obj/machinery/atmospherics/unary/vent_pump/on
	use_power = POWER_USE_IDLE
	icon_state = "map_vent_out"

/obj/machinery/atmospherics/unary/vent_pump/siphon
	pump_direction = 0

/obj/machinery/atmospherics/unary/vent_pump/siphon/on
	use_power = POWER_USE_IDLE
	icon_state = "map_vent_in"

/obj/machinery/atmospherics/unary/vent_pump/siphon/on/atmos
	use_power = POWER_USE_IDLE
	icon_state = "map_vent_in"
	external_pressure_bound = 0
	external_pressure_bound_default = 0
	internal_pressure_bound = MAX_PUMP_PRESSURE
	internal_pressure_bound_default = MAX_PUMP_PRESSURE
	pressure_checks = 2
	pressure_checks_default = 2

/obj/machinery/atmospherics/unary/vent_pump/Initialize()
	. = ..()
	var/area/area = get_area(src)
	if (area)
		LAZYADD(area.vent_pumps, src)
	air_contents.volume = ATMOS_DEFAULT_VOLUME_PUMP
	icon = null

/obj/machinery/atmospherics/unary/vent_pump/Destroy()
	var/area/area = get_area(src)
	if(area)
		area.air_vent_info -= id_tag
		area.air_vent_names -= id_tag
		LAZYREMOVE(area.vent_pumps, src)
	return ..()

/obj/machinery/atmospherics/unary/vent_pump/high_volume
	name = "Large Air Vent"
	power_channel = EQUIP
	power_rating = 45000

/obj/machinery/atmospherics/unary/vent_pump/high_volume/Initialize()
	. = ..()
	air_contents.volume = ATMOS_DEFAULT_VOLUME_PUMP + 800


/obj/machinery/atmospherics/unary/vent_pump/on_update_icon(safety = 0)
	if(!check_icon_cache())
		return
	if (!node)
		return

	ClearOverlays()

	var/vent_icon = "vent"

	var/turf/T = get_turf(src)
	if(!istype(T))
		return

	if(!T.is_plating() && node && node.level == ATOM_LEVEL_UNDER_TILE && istype(node, /obj/machinery/atmospherics/pipe))
		vent_icon += "h"

	if(welded)
		vent_icon += "weld"
	else if(!powered())
		vent_icon += "off"
	else
		vent_icon += "[use_power ? "[pump_direction ? "out" : "in"]" : "off"]"

	AddOverlays(icon_manager.get_atmos_icon("device", , , vent_icon))

/obj/machinery/atmospherics/unary/vent_pump/update_underlays()
	if(..())
		underlays.Cut()
		var/turf/T = get_turf(src)
		if(!istype(T))
			return
		if(!T.is_plating() && node && node.level == ATOM_LEVEL_UNDER_TILE && istype(node, /obj/machinery/atmospherics/pipe))
			return
		else
			if(node)
				add_underlay(T, node, dir, node.icon_connect_type)
			else
				add_underlay(T,, dir)

/obj/machinery/atmospherics/unary/vent_pump/hide()
	update_icon()
	update_underlays()

/obj/machinery/atmospherics/unary/vent_pump/proc/can_pump()
	if(inoperable())
		return 0
	if(!use_power)
		return 0
	if(welded)
		return 0
	return 1

/obj/machinery/atmospherics/unary/vent_pump/Process()
	..()

	if (hibernate > world.time)
		return 1

	if (!node)
		update_use_power(POWER_USE_OFF)
	if(!can_pump())
		return 0

	var/datum/gas_mixture/environment = loc.return_air()

	var/power_draw = -1

	//Figure out the target pressure difference
	var/pressure_delta = get_pressure_delta(environment)

	if((environment.temperature || air_contents.temperature) && pressure_delta > 0.5)
		if(pump_direction) //internal -> external
			var/transfer_moles = calculate_transfer_moles(air_contents, environment, pressure_delta)
			power_draw = pump_gas(src, air_contents, environment, transfer_moles, power_rating)
		else //external -> internal
			var/transfer_moles = calculate_transfer_moles(environment, air_contents, pressure_delta, (network)? network.volume : 0)

			//limit flow rate from turfs
			transfer_moles = min(transfer_moles, environment.total_moles*air_contents.volume/environment.volume)	//group_multiplier gets divided out here
			power_draw = pump_gas(src, environment, air_contents, transfer_moles, power_rating)

	else
		//If we're in an area that is fucking ideal, and we don't have to do anything, chances are we won't next tick either so why redo these calculations?
		//JESUS FUCK.  THERE ARE LITERALLY 250 OF YOU MOTHERFUCKERS ON ZLEVEL ONE AND YOU DO THIS SHIT EVERY TICK WHEN VERY OFTEN THERE IS NO REASON TO
		if(pump_direction && pressure_checks == PRESSURE_CHECK_EXTERNAL) //99% of all vents
			hibernate = world.time + (rand(100,200))


	if (power_draw >= 0)
		last_power_draw = power_draw
		use_power_oneoff(power_draw)
		if(network)
			network.update = 1

	return 1

/obj/machinery/atmospherics/unary/vent_pump/proc/get_pressure_delta(datum/gas_mixture/environment)
	var/pressure_delta = DEFAULT_PRESSURE_DELTA
	var/environment_pressure = environment.return_pressure()

	if(pump_direction) //internal -> external
		if(pressure_checks & PRESSURE_CHECK_EXTERNAL)
			pressure_delta = min(pressure_delta, external_pressure_bound - environment_pressure) //increasing the pressure here
		if(pressure_checks & PRESSURE_CHECK_INTERNAL)
			pressure_delta = min(pressure_delta, air_contents.return_pressure() - internal_pressure_bound) //decreasing the pressure here
	else //external -> internal
		if(pressure_checks & PRESSURE_CHECK_EXTERNAL)
			pressure_delta = min(pressure_delta, environment_pressure - external_pressure_bound) //decreasing the pressure here
		if(pressure_checks & PRESSURE_CHECK_INTERNAL)
			pressure_delta = min(pressure_delta, internal_pressure_bound - air_contents.return_pressure()) //increasing the pressure here

	return pressure_delta

/obj/machinery/atmospherics/unary/vent_pump/area_uid()
	return controlled ? ..() : "NONE"

/obj/machinery/atmospherics/unary/vent_pump/Initialize()
	if (!id_tag)
		id_tag = num2text(sequential_id("obj/machinery"))
	if(controlled)
		var/area/A = get_area(src)
		if(A && !A.air_vent_names[id_tag])
			var/new_name = "[A.name] Vent Pump #[length(A.air_vent_names)+1]"
			A.air_vent_names[id_tag] = new_name
			SetName(new_name)
	. = ..()

/obj/machinery/atmospherics/unary/vent_pump/proc/purge()
	pressure_checks &= ~PRESSURE_CHECK_EXTERNAL
	pump_direction = 0

/obj/machinery/atmospherics/unary/vent_pump/refresh()
	..()
	hibernate = FALSE
	toggle_input_toggle()

/obj/machinery/atmospherics/unary/vent_pump/RefreshParts()
	. = ..()
	toggle_input_toggle()

/obj/machinery/atmospherics/unary/vent_pump/examine(mob/user, distance)
	. = ..()
	if(distance <= 1)
		to_chat(user, "A small gauge in the corner reads [round(last_flow_rate, 0.1)] L/s; [round(last_power_draw)] W")
	else
		to_chat(user, "You are too far away to read the gauge.")
	if(welded)
		to_chat(user, "It seems welded shut.")

/obj/machinery/atmospherics/unary/vent_pump/use_tool(obj/item/W, mob/living/user, list/click_params)
	if(isWrench(W))
		if (is_powered() && use_power)
			to_chat(user, SPAN_WARNING("You cannot unwrench \the [src], turn it off first."))
			return TRUE
		var/turf/T = src.loc
		if (node && node.level==ATOM_LEVEL_UNDER_TILE && isturf(T) && !T.is_plating())
			to_chat(user, SPAN_WARNING("You must remove the plating first."))
			return TRUE
		var/datum/gas_mixture/int_air = return_air()
		var/datum/gas_mixture/env_air = loc.return_air()
		if ((int_air.return_pressure()-env_air.return_pressure()) > 2*ONE_ATMOSPHERE)
			to_chat(user, SPAN_WARNING("You cannot unwrench \the [src], it is too exerted due to internal pressure."))
			return TRUE
		playsound(src.loc, 'sound/items/Ratchet.ogg', 50, 1)
		to_chat(user, SPAN_NOTICE("You begin to unfasten \the [src]..."))
		if (!do_after(user, (W.toolspeed * 4) SECONDS, src, DO_REPAIR_CONSTRUCT))
			return TRUE
		user.visible_message( \
			SPAN_NOTICE("\The [user] unfastens \the [src]."), \
			SPAN_NOTICE("You have unfastened \the [src]."), \
			"You hear a ratchet.")
		new /obj/item/pipe(loc, src)
		qdel(src)
		return TRUE

	if(isMultitool(W))
		var/datum/browser/popup = new(user, "Vent Configuration Utility", "[src] Configuration Panel", 600, 200)
		popup.set_content(jointext(get_console_data(),"<br>"))
		popup.open()
		return TRUE

	if (isWelder(W))
		var/obj/item/weldingtool/WT = W

		if(!WT.can_use(1,user))
			return TRUE

		to_chat(user, SPAN_NOTICE("Now welding \the [src]."))
		playsound(src, 'sound/items/Welder.ogg', 50, 1)

		if(!do_after(user, (W.toolspeed * 2) SECONDS, src, DO_REPAIR_CONSTRUCT))
			return TRUE

		if(!src || !WT.remove_fuel(1, user))
			return TRUE

		welded = !welded
		update_icon()
		playsound(src, 'sound/items/Welder2.ogg', 50, 1)
		user.visible_message(
			SPAN_NOTICE("\The [user] [welded ? "welds \the [src] shut" : "unwelds \the [src]"]."), \
			SPAN_NOTICE("You [welded ? "weld \the [src] shut" : "unweld \the [src]"]."), \
			"You hear welding.")
		return TRUE

	return ..()

/obj/machinery/atmospherics/unary/vent_pump/proc/get_console_data()
	. = list()
	. += "<table>"
	. += "<tr><td><b>Name:</b></td><td>[name]</td>"
	. += "<tr><td><b>Pump Status:</b></td><td>[pump_direction ? SPAN_COLOR("green", "Releasing") : SPAN_COLOR("red", "Siphoning")]</td><td><a href='byond://?src=\ref[src];switchMode=\ref[src]'>Toggle</a></td></tr>"
	. = jointext(., null)

/obj/machinery/atmospherics/unary/vent_pump/OnTopic(mob/user, href_list, datum/topic_state/state)
	if((. = ..()))
		return
	if(href_list["switchMode"])
		pump_direction = !pump_direction
		to_chat(user, SPAN_NOTICE("The multitool emits a short beep confirming the change."))
		queue_icon_update() //force the icon to refresh after changing directional mode.
		return TOPIC_REFRESH

/singleton/public_access/public_variable/pump_dir
	expected_type = /obj/machinery/atmospherics/unary/vent_pump
	name = "pump direction"
	desc = "The pump mode of the vent. Expected values are \"siphon\" or \"release\"."
	can_write = TRUE
	has_updates = TRUE
	var_type = IC_FORMAT_STRING

/singleton/public_access/public_variable/pump_dir/access_var(obj/machinery/atmospherics/unary/vent_pump/machine)
	return machine.pump_direction ? "release" : "siphon"

/singleton/public_access/public_variable/pump_dir/write_var(obj/machinery/atmospherics/unary/vent_pump/machine, new_value)
	if(!(new_value in list("release", "siphon")))
		return FALSE
	. = ..()
	if(.)
		machine.pump_direction = (new_value == "release")

/singleton/public_access/public_variable/pump_checks
	expected_type = /obj/machinery/atmospherics/unary/vent_pump
	name = "pump checks"
	desc = "Numerical codes for whether the pump checks internal or internal pressure (or both) prior to operating. Can also be supplied the string keyword \"default\"."
	can_write = TRUE
	has_updates = FALSE
	var_type = IC_FORMAT_ANY

/singleton/public_access/public_variable/pump_checks/access_var(obj/machinery/atmospherics/unary/vent_pump/machine)
	return machine.pressure_checks

/singleton/public_access/public_variable/pump_checks/write_var(obj/machinery/atmospherics/unary/vent_pump/machine, new_value)
	if(new_value == "default")
		new_value = machine.pressure_checks_default
	var/sanitized = sanitize_integer(new_value, 0, 3)
	if(new_value != sanitized)
		return FALSE
	. = ..()
	if(.)
		machine.pressure_checks = new_value

/singleton/public_access/public_variable/pressure_bound
	expected_type = /obj/machinery/atmospherics/unary/vent_pump
	name = "internal pressure bound"
	desc = "The bound on internal pressure used in checks (a number). When writing, can be supplied the string keyword \"default\" instead."
	can_write = TRUE
	has_updates = FALSE
	var_type = IC_FORMAT_ANY

/singleton/public_access/public_variable/pressure_bound/access_var(obj/machinery/atmospherics/unary/vent_pump/machine)
	return machine.internal_pressure_bound

/singleton/public_access/public_variable/pressure_bound/write_var(obj/machinery/atmospherics/unary/vent_pump/machine, new_value)
	if(new_value == "default")
		new_value = machine.internal_pressure_bound_default
	new_value = clamp(text2num(new_value), 0, MAX_PUMP_PRESSURE)
	. = ..()
	if(.)
		machine.internal_pressure_bound = new_value

/singleton/public_access/public_variable/pressure_bound/external
	expected_type = /obj/machinery/atmospherics/unary/vent_pump
	name = "external pressure bound"
	desc = "The bound on external pressure used in checks (a number). When writing, can be supplied the string keyword \"default\" instead."

/singleton/public_access/public_variable/pressure_bound/external/access_var(obj/machinery/atmospherics/unary/vent_pump/machine)
	return machine.external_pressure_bound

/singleton/public_access/public_variable/pressure_bound/external/write_var(obj/machinery/atmospherics/unary/vent_pump/machine, new_value)
	if(new_value == "default")
		new_value = machine.external_pressure_bound_default
	new_value = clamp(text2num(new_value), 0, MAX_PUMP_PRESSURE)
	. = ..()
	if(.)
		machine.external_pressure_bound = new_value

/singleton/public_access/public_method/purge_pump
	name = "activate purge mode"
	desc = "Activates purge mode, overriding pressure checks and removing air."
	call_proc = TYPE_PROC_REF(/obj/machinery/atmospherics/unary/vent_pump, purge)

/singleton/stock_part_preset/radio/event_transmitter/vent_pump
	frequency = PUMP_FREQ
	filter = RADIO_TO_AIRALARM
	event = /singleton/public_access/public_variable/input_toggle
	transmit_on_event = list(
		"area" = /singleton/public_access/public_variable/area_uid,
		"device" = /singleton/public_access/public_variable/identifier,
		"power" = /singleton/public_access/public_variable/use_power,
		"direction" = /singleton/public_access/public_variable/pump_dir,
		"checks" = /singleton/public_access/public_variable/pump_checks,
		"internal" = /singleton/public_access/public_variable/pressure_bound,
		"external" = /singleton/public_access/public_variable/pressure_bound/external,
		"power_draw" = /singleton/public_access/public_variable/power_draw,
		"flow_rate" = /singleton/public_access/public_variable/flow_rate
	)

/singleton/stock_part_preset/radio/receiver/vent_pump
	frequency = PUMP_FREQ
	filter = RADIO_FROM_AIRALARM
	receive_and_call = list(
		"power_toggle" = /singleton/public_access/public_method/toggle_power,
		"purge" = /singleton/public_access/public_method/purge_pump,
		"status" = /singleton/public_access/public_method/refresh
	)
	receive_and_write = list(
		"set_power" = /singleton/public_access/public_variable/use_power,
		"set_direction" = /singleton/public_access/public_variable/pump_dir,
		"set_checks" = /singleton/public_access/public_variable/pump_checks,
		"set_internal_pressure" = /singleton/public_access/public_variable/pressure_bound,
		"set_external_pressure" = /singleton/public_access/public_variable/pressure_bound/external,
		"init" = /singleton/public_access/public_variable/name
	)

/singleton/stock_part_preset/radio/receiver/vent_pump/tank
	frequency = ATMOS_TANK_FREQ
	filter = RADIO_ATMOSIA

/singleton/stock_part_preset/radio/event_transmitter/vent_pump/tank
	frequency = ATMOS_TANK_FREQ
	filter = RADIO_ATMOSIA

/obj/machinery/atmospherics/unary/vent_pump/tank
	controlled = FALSE
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump/tank = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump/tank = 1
	)

/obj/machinery/atmospherics/unary/vent_pump/siphon/on/atmos/tank
	controlled = FALSE
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump/tank = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump/tank = 1
	)

/singleton/stock_part_preset/radio/receiver/vent_pump/external_air
	frequency = EXTERNAL_AIR_FREQ

/singleton/stock_part_preset/radio/event_transmitter/vent_pump/external_air
	frequency = EXTERNAL_AIR_FREQ
	filter = RADIO_AIRLOCK

/obj/machinery/atmospherics/unary/vent_pump/high_volume/external_air
	controlled = FALSE
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump/external_air = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump/external_air = 1
	)

/singleton/stock_part_preset/radio/receiver/vent_pump/shuttle
	frequency = SHUTTLE_AIR_FREQ

/singleton/stock_part_preset/radio/event_transmitter/vent_pump/shuttle
	frequency = SHUTTLE_AIR_FREQ
	filter = RADIO_AIRLOCK

/obj/machinery/atmospherics/unary/vent_pump/high_volume/shuttle
	controlled = FALSE
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump/shuttle = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump/shuttle = 1
	)

/singleton/stock_part_preset/radio/event_transmitter/vent_pump/shuttle/aux
	filter = RADIO_TO_AIRALARM

// This is intended for hybrid airlock-room setups, where unlike the above, this one is controlled by the air alarm and attached to the internal atmos system.
/obj/machinery/atmospherics/unary/vent_pump/shuttle_auxiliary
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump/shuttle = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump/shuttle/aux = 1
	)

/singleton/stock_part_preset/radio/receiver/vent_pump/airlock
	frequency = AIRLOCK_AIR_FREQ

/singleton/stock_part_preset/radio/event_transmitter/vent_pump/airlock
	frequency = AIRLOCK_AIR_FREQ
	filter = RADIO_AIRLOCK

/obj/machinery/atmospherics/unary/vent_pump/high_volume/airlock
	controlled = FALSE
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump/airlock = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump/airlock = 1
	)

/singleton/stock_part_preset/radio/receiver/vent_pump/engine
	frequency = ATMOS_ENGINE_FREQ
	filter = RADIO_ATMOSIA

/singleton/stock_part_preset/radio/event_transmitter/vent_pump/engine
	frequency = ATMOS_ENGINE_FREQ
	filter = RADIO_ATMOSIA

/obj/machinery/atmospherics/unary/vent_pump/engine
	name = "Engine Core Vent"
	power_channel = ENVIRON
	power_rating = 30000
	controlled = FALSE
	stock_part_presets = list(
		/singleton/stock_part_preset/radio/receiver/vent_pump/engine = 1,
		/singleton/stock_part_preset/radio/event_transmitter/vent_pump/engine = 1
	)

/obj/machinery/atmospherics/unary/vent_pump/engine/Initialize()
	. = ..()
	air_contents.volume = ATMOS_DEFAULT_VOLUME_PUMP + 500 //meant to match air injector

#undef DEFAULT_PRESSURE_DELTA

#undef EXTERNAL_PRESSURE_BOUND
#undef INTERNAL_PRESSURE_BOUND
#undef PRESSURE_CHECKS

#undef PRESSURE_CHECK_EXTERNAL
#undef PRESSURE_CHECK_INTERNAL
