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
}