/datum/power/changeling/fakedeath
	name = "Regenerative Stasis"
	desc = "We become weakened to a death-like state, where we will rise again from death."
	helptext = "Can be used before or after death. Duration varies greatly."
	ability_icon_state = "ling_regenerative_stasis"
	genomecost = 0
	allowduringlesserform = 1
	verbpath = /mob/proc/changeling_fakedeath
/mob/proc/finish_revive()
	//The ling will now be able to choose when to revive
	verbs += /mob/proc/changeling_revive
	new /obj/changeling_revive_holder(src)
	to_chat(src, "<span class='notice'><font size='5'>We are ready to rise.  Use the <b>Revive</b> verb when you are ready.</font></span>")
//Fake our own death and fully heal. You will appear to be dead but regenerate fully after a short delay.
/mob/proc/changeling_fakedeath()
	set category = "Changeling"
	set name = "Regenerative Stasis (20)"

	var/datum/changeling/changeling = changeling_power(CHANGELING_STASIS_COST,1,100,DEAD)
	if(!changeling)
		return

	var/mob/living/carbon/C = src
	for (var/obj/item/organ/internal/augment/lingcore/core in C.internal_organs)
		if (!core.stasiscount)
			to_chat(usr, SPAN_WARNING("Our core is decayed. It cannot help us, now."))
			return FALSE

	if(changeling.max_geneticpoints < 0) //Absorbed by another ling
		to_chat(src, SPAN_WARNING("We have no genomes, not even our own, and cannot regenerate."))
		return FALSE

	if(!C.stat && alert("Are we sure we wish to regenerate?  We will appear to be dead while doing so.","Revival","Yes","No") == "No")
		return
	to_chat(C, SPAN_NOTICE("We will attempt to regenerate our form."))

	C.UpdateLyingBuckledAndVerbStatus()
	C.remove_changeling_powers()
	C.status_flags |= FAKEDEATH
	changeling.chem_charges -= CHANGELING_STASIS_COST

	if(C.stat != DEAD)
		C.adjustOxyLoss(C.maxHealth * 2)
	addtimer(new Callback(src, TYPE_PROC_REF(/mob, finish_revive)),rand(2 MINUTES, 4 MINUTES))

	return TRUE
