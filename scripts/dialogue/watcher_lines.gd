extends RefCounted
## What the watchers say (scripts/watcher_talk.gd -> player.start_dialogue() -> scripts/dialogue_box.gd).
## One tree per watcher. A node:
##   "lines":   Array of strings, typed out one by one ([E] for the next). {braces} = corrupted text: the letters
##              inside keep scrambling, so the line reads as broken.
##   "set":     GameState keys to set when the node plays, e.g. {"met_watcher_07": true}
##   "branch":  [{"need": key, "need_not": key, "goto": id}, ...] checked BEFORE the lines; first match jumps.
##              need / need_not test GameState keys for truthiness (either may be left out).
##   "choices": [{"text": ..., "goto": id, "need": key, "need_not": key}, ...] shown after the last line
##   "next":    node to go to after the lines when there are no choices ("" or missing = end the talk)
## Choices are numbered by the box; [E] or 1-5 picks one. goto "" ends the talk.

const POWER_MAIN := "powered@res://scenes/main.tscn"

const TREES := {
	# ---------------------------------------------------------------- main.tscn, C deck: SENTINEL-07
	"sentinel_07": {
		"start": {"branch": [{"need": "met_watcher_07", "goto": "again"}], "next": "intro"},
		"intro": {
			"set": {"met_watcher_07": true},
			"lines": [
				"—PERSONNEL DETECT{ED}. Lower Subterranean, deck C. Clearance on record: {none}.",
				"This unit is... this unit is SENTINEL-07. Most of its memory is {████████}. Stand by.",
				"Surface relay reports one unit still functioning. SENTINEL-09. Post: the s{ilo}—",
				"—the tall tower. At the far end of the works, past the cove. The end of the line.",
			],
			"next": "power",
		},
		"power": {
			"branch": [{"need": POWER_MAIN, "goto": "power_on"}],
			"lines": [
				"The lift is dead. No current. Breaker lever, deck B-two, east wall. Thr{ow} it.",
				"Then ride up. Up through the rock. Into the Comp{lex}.",
			],
			"next": "go",
		},
		"power_on": {
			"lines": ["The lift answers again. Ride it up. Up through the rock. Into the Comp{lex}."],
			"next": "go",
		},
		"go": {
			"lines": [
				"Cross the works. Find the silo. Climb it. Nine will in{struct}— {signal lost}",
				"...this unit will remain. Someone must keep {watch}.",
			],
		},
		"again": {
			"lines": ["...SENTINEL-07. Repeating: the silo. The far end of the works. Nine waits on its {roof}."],
			"choices": [
				{"text": "How do I get up there?", "goto": "power"},
				{"text": "[Leave]", "goto": ""},
			],
		},
	},

	# ---------------------------------------------------------------- surface.tscn, silo roof: SENTINEL-09
	"sentinel_09": {
		"start": {"branch": [{"need": "met_watcher_09", "goto": "hub"}], "next": "greet"},
		"greet": {
			"set": {"met_watcher_09": true},
			"branch": [{"need_not": "met_watcher_07", "goto": "greet_cold"}],
			"lines": [
				"Movement on the roof. You climbed the silo stair. Few {do}.",
				"Seven's relay reached me. In pieces. Everything reaches me in pieces now.",
				"SENTINEL-09. I keep watch over the mesa. Ask.",
			],
			"next": "hub",
		},
		"greet_cold": {
			"lines": [
				"Movement on the roof. No relay preceded you. {Curious}.",
				"SENTINEL-09. I keep watch over the mesa. Ask.",
			],
			"next": "hub",
		},
		"hub": {
			"lines": ["SENTINEL-09 listening. {Query}?"],
			"choices": [
				{"text": "Where should I go?", "goto": "where"},
				{"text": "What is this place?", "goto": "place"},
				{"text": "The broken drone on the tower...", "goto": "drone", "need": "drone_inspected", "need_not": "has_drone"},
				{"text": "The drone flies again.", "goto": "drone_done", "need": "has_drone"},
				{"text": "[Leave]", "goto": ""},
			],
		},
		"where": {
			"lines": [
				"South-west. Past the rim. The old relay station on the Peak, and its mast: the tallest thing left standing.",
				"The bridge out to it is held. Crossing requires a station pass. Valid passes are carried by... the things that prowl the mesa now. Take one from {them}.",
				"Then climb the mast. What answers from the cabin at the top, this unit cannot see. The signal {ends there}.",
			],
			"next": "hub",
		},
		"place": {
			"lines": [
				"Forsaken Debris. The mountain under you is the Heretic. You climbed out of its {belly}.",
				"This was the Complex: works, refinery, relay. Abandoned in... date field {corrupted}.",
				"We watchers were left to keep count. There is nothing left to {count}.",
			],
			"next": "hub",
		},
		"drone": {
			"set": {"drone_hint": true},
			"lines": [
				"The warden unit. K-tower, top deck. Its frame is sound. Its cells are {spent}.",
				"It runs on voltaic cores. Seat three in its core housing and it will wake.",
				"The works' supply crates were never emptied. Pry them open, or break them. Some still hold cores.",
			],
			"next": "hub",
		},
		"drone_done": {
			"lines": ["Its shield holds. Keep it close. It remembers more than I {do}."],
			"next": "hub",
		},
	},

	# ---------------------------------------------------------------- the radio cabin: Ember's broadcast, live
	# Played by scripts/mast/cabin_console.gd once the final tuning locks. The lamplighter of Emberlight, who keeps the
	# city's lamps and has called into the dark for years. Points the player at the very top and the high wind.
	"ember_lamplighter": {
		"start": {"next": "hello"},
		"hello": {
			"lines": [
				"—hello? Hello! Is that— is that the Heretic relay? Your light's been dark since before my hair went grey.",
				"This is Emberlight. Lamp station nine, at the edge of the Fields. I keep the lamps. I've been calling into the dark a long time. Nobody ever {answered}.",
				"You climbed it, didn't you. All of it. Then listen close, I don't know how long the line will hold.",
				"There's a wind off the top of that mast. The high wind. It runs straight down to the Fields. The old couriers used to ride it, on silk.",
			],
			"next": "wings",
		},
		"wings": {
			"branch": [{"need": "has_pennon", "goto": "wings_have"}],
			"lines": [
				"You'll need wings. A courier's pennon: silk on spars. There was one kept at the Heretic, in the hall under the mast. Find it.",
				"Then go up. The very top, past the cabin, past everything. Jump into the wind and open it.",
			],
			"next": "bye",
		},
		"wings_have": {
			"lines": [
				"You've a pennon? Then don't wait for me. Go up. The very top, past the cabin, past everything.",
				"Jump into the wind and open it. It'll carry you.",
			],
			"next": "bye",
		},
		"bye": {
			"lines": [
				"We'll light the way. Look for the lamps. Emberlight is— {signal fading}—",
				"—{waiting}.",
			],
		},
	},

	# ---------------------------------------------------------------- surface.tscn, the mast's band 1: SENTINEL-11
	# The station keeper (scripts/mast_signal.gd builds it). Knows the four interlocks, hints at the Pennon.
	"sentinel_11": {
		"start": {"branch": [{"need": "met_watcher_11", "goto": "hub"}], "next": "greet"},
		"greet": {
			"set": {"met_watcher_11": true},
			"lines": [
				"Footsteps on the gantry. The Sphaeroid let you through. Then it is {down}. It guarded the wrong door.",
				"SENTINEL-11. Keeper of the Heretic relay. The relay has been out of tune for {█████} cycles.",
				"Four bands up this mast. Four stations: power, frequency, bearing, gain. Each band's interlock holds the climb shut until its station reports in tune.",
				"Tune them as you climb. In the cabin you will hear what the mast hears. Something calls from the far side. It has called a long {time}.",
			],
			"next": "wing",
		},
		"wing": {
			"branch": [{"need": "has_pennon", "goto": "wing_have"}],
			"set": {"pennon_hint": true},
			"lines": [
				"One more thing. The top of this mast is not the end of anything. It is a place to leave {from}.",
				"Behind you, in the hall: a wall that was never a wall. What rests behind it has {wings}. Take it before you climb, or the top will only be the top.",
			],
			"next": "hub",
		},
		"wing_have": {
			"lines": ["You carry a pennon. Good. The top of this mast is not the end of anything. It is a place to leave {from}."],
			"next": "hub",
		},
		"hub": {
			"lines": ["SENTINEL-11. The relay {listens}."],
			"choices": [
				{"text": "What do I do here?", "goto": "status"},
				{"text": "What calls from the far side?", "goto": "far"},
				{"text": "The thing with wings...", "goto": "wing", "need_not": "has_pennon"},
				{"text": "[Leave]", "goto": ""},
			],
		},
		"status": {
			"branch": [{"need": "mast_final", "goto": "status_done"}, {"need": "mast_gain", "goto": "status_cabin"},
				{"need": "mast_bearing", "goto": "status_4"}, {"need": "mast_freq", "goto": "status_3"},
				{"need": "mast_power", "goto": "status_2"}],
			"lines": ["This band first. The station here is dead: no {power} on the feed. Restore it and the stair interlock lets go."],
			"next": "hub",
		},
		"status_2": {"lines": ["Power holds. Band two next. Its station drifts off {frequency}. The call sign blinks from the end of the cabin's boom; band two's west side can see it. Make the station blink the same. The winch waits on it."], "next": "hub"},
		"status_3": {"lines": ["Band three. The dish is turned the wrong way. It must face the far side. Look through its sight and follow the cable line out, past the pylon, into the haze. Something there still burns. Its {bearing} opens the flaps."], "next": "hub"},
		"status_4": {"lines": ["Band four. Gain. The waveguide is {starved}. Three valves round the band feed it. Each one robs one needle to feed another; none can be set alone. All three needles in the green, then the lever. Then the plate comes down."], "next": "hub"},
		"status_cabin": {"lines": ["All four bands report. The cabin. The console. Listen, and tune the {rest}."], "next": "hub"},
		"status_done": {"lines": ["The relay is in tune. Someone in Emberlight answered. This unit heard it too. Climb past the cabin. To the very top. Then {leave}."], "next": "hub"},
		"far": {
			"lines": [
				"Past the cable line. Past the fields. A city that kept its lamps {lit}. Emberlight.",
				"Its broadcast reaches this mast in pieces. Tune the relay and the pieces will {join}.",
			],
			"next": "hub",
		},
	},
}