//	Observer Pattern Implementation: Moved
//		Registration type: /atom/movable
//
//		Raised when: An /atom/movable instance has moved using Move() or forceMove().
//
//		Arguments that the called proc should expect:
//			/atom/movable/moving_instance: The instance that moved
//			/atom/old_loc: The loc before the move.
//			/atom/new_loc: The loc after the move.

GLOBAL_TYPED_NEW(moved_event, /singleton/observ/moved)

/singleton/observ/moved
	name = "Moved"
	expected_type = /atom/movable

/singleton/observ/moved/register(atom/movable/mover, datum/listener, proc_call)
	. = ..()

	// Listen to the parent if possible.
	if(. && istype(mover.loc, expected_type))
		register(mover.loc, mover, TYPE_PROC_REF(/atom/movable, recursive_move))

/********************
* Movement Handling *
********************/

/atom/Entered(atom/movable/am, atom/old_loc)
	. = ..()
	GLOB.moved_event.raise_event(am, old_loc, am.loc)

/atom/movable/Entered(atom/movable/am, atom/old_loc)
	. = ..()
	if(GLOB.moved_event.has_listeners(am))
		GLOB.moved_event.register(src, am, TYPE_PROC_REF(/atom/movable, recursive_move))

/atom/movable/Exited(atom/movable/am, atom/new_loc)
	. = ..()
	GLOB.moved_event.unregister(src, am, TYPE_PROC_REF(/atom/movable, recursive_move))
