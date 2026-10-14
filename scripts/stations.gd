extends RefCounted
## The journey as data. Stations, the trails between them and the temple at
## the peak are all entries here; a new one is content, not a new code path.
##
## A station is a set of connected areas. Each area is a belt-scroll street:
## buildings stand along the back, people walk in the depth band in front, and
## exits at the left and right edges lead to neighbouring areas.
## Building kinds: house, stall, inn, den, shrine, gate, bridge, temple. Any
## building may carry a "style" that overrides the kind's look (see kit.gd).
##   pay     coins the owner pays for a repair
##   loot    coins the oni scatters when it smashes the building
##   pantry  food the oni can eat per night
##   barrels sake the oni can drink per night
## Hides are places the oni can press into; max_scale is the largest oni that fits.
## Doors join a town's streets into a small network: walk up into an alley at
## the back ("up") or down off the front edge ("down") to reach another street.
## A well is a water source for the monk. A river with a "ferry" has no
## bridge: the monk pays, works or wades to cross, and a station marked
## "must_cross" in ROUTE can only be left from the far side. Blockers are people
## who stand in the street by day and must be dealt with to pass.
## NPC entries are looks for kit.person, placed relative to a building.
## "start" is where the road from behind comes into a station, "end" where the
## road on along the route does (the oni walks both ways in the hunt).
## A building may start damaged or in ruins ("hp" below 100). A station with
## "people": false is abandoned: no watch, no rumour, and at night the yokai
## listed in each area's "yokai" walk its streets.

## The road. Each station lists the stations it leads to and the trail walked
## to reach each one. Where a station has two roads, the map lets you choose.
const ROUTE := {
	"village": {"name": "the mountain village", "pos": Vector2(60, 215), "next": ["post_town"], "trails": {"post_town": "cedar_trail"}},
	"post_town": {"name": "the post town", "pos": Vector2(165, 150), "next": ["river_crossing", "ruined_town", "castle_town"],
		"trails": {"river_crossing": "paddy_road", "ruined_town": "old_road", "castle_town": "high_pass"}},
	"ruined_town": {"name": "the abandoned post town", "pos": Vector2(240, 92), "next": ["castle_town"], "trails": {"castle_town": "castle_road"}},
	"river_crossing": {"name": "the river crossing", "pos": Vector2(255, 215), "next": ["castle_town"], "trails": {"castle_town": "castle_road"},
		"must_cross": true},
	"castle_town": {"name": "the castle town", "pos": Vector2(330, 120), "next": ["peak"], "trails": {"peak": "mountain_trail"}},
	"peak": {"name": "the mountain temple", "pos": Vector2(425, 45), "next": []},
}

## Trails are walked by day. "slope" lists [x, height] points: the path climbs
## where the height rises, and walking uphill is slower and more tiring.
const TRAILS := {
	"cedar_trail": {
		"name": "the cedar forest trail",
		"width": 1100,
		"backdrop": "forest",
		"ground": "forest",
		"slope": [[0, 0], [400, 18], [700, 18], [1100, 34]],
		"camp": {"x": 520, "w": 340, "look": "abandoned camp"},
		"forage": {"a": 60, "b": 200},
		"foes": {"gaki": 3, "kasa": 2},
		"props": [
			{"kind": "cedar", "x": 60, "h": 70}, {"kind": "cedar", "x": 150, "h": 80}, {"kind": "waterfall", "x": 250, "h": 70},
			{"kind": "cedar", "x": 330, "h": 66}, {"kind": "stone_lantern", "x": 420}, {"kind": "cedar", "x": 600, "h": 84},
			{"kind": "rock", "x": 700, "s": 12}, {"kind": "cedar", "x": 820, "h": 72}, {"kind": "cedar", "x": 980, "h": 78},
		],
	},
	"paddy_road": {
		"name": "the paddy road",
		"width": 1100,
		"backdrop": "hills",
		"ground": "earth",
		"slope": [[0, 20], [500, 0], [1100, -10]],
		"camp": {"x": 560, "w": 300, "look": "irrigation channels"},
		"forage": {"a": 300, "b": 460},
		"foes": {"kappa": 3},
		"props": [
			{"kind": "paddies", "x": 80, "w": 360}, {"kind": "rock", "x": 470, "s": 8}, {"kind": "paddies", "x": 520, "w": 400},
			{"kind": "stone_lantern", "x": 960}, {"kind": "cedar", "x": 1040, "h": 62},
		],
	},
	"old_road": {
		"name": "the old road",
		"width": 1100,
		"backdrop": "forest",
		"ground": "forest",
		"slope": [[0, 0], [350, 25], [700, 10], [1100, 30]],
		"camp": {"x": 500, "w": 360, "look": "collapsed tollhouse"},
		"forage": {"a": 150, "b": 330},
		"foes": {"kasa": 2, "onibi": 2, "kitsune": 1},
		"props": [
			{"kind": "cedar", "x": 70, "h": 84}, {"kind": "stone_lantern", "x": 140}, {"kind": "cedar", "x": 380, "h": 90},
			{"kind": "rock", "x": 450, "s": 12}, {"kind": "cedar", "x": 880, "h": 80}, {"kind": "torii", "x": 1000, "h": 46},
		],
	},
	"castle_road": {
		"name": "the castle road",
		"width": 1100,
		"backdrop": "hills",
		"ground": "earth",
		"slope": [[0, -10], [500, 10], [1100, 30]],
		"camp": {"x": 480, "w": 360, "look": "burned teahouse"},
		"forage": {"a": 120, "b": 300},
		"foes": {"gaki": 2, "kitsune": 2, "onibi": 1},
		"props": [
			{"kind": "cedar", "x": 90, "h": 70}, {"kind": "stone_lantern", "x": 200}, {"kind": "rock", "x": 320, "s": 10},
			{"kind": "cedar", "x": 760, "h": 74}, {"kind": "castle", "x": 1000}, {"kind": "stone_lantern", "x": 900},
		],
	},
	"high_pass": {
		"name": "the high pass",
		"width": 1300,
		"backdrop": "peaks",
		"ground": "stone",
		"slope": [[0, 0], [450, 80], [800, 90], [1300, 30]],
		"camp": {"x": 560, "w": 380, "look": "snowbound shelter"},
		"forage": {"a": 120, "b": 300},
		"foes": {"tengu": 3, "onibi": 3, "gaki": 1},
		"props": [
			{"kind": "torii", "x": 80, "h": 44}, {"kind": "rock", "x": 230, "s": 14}, {"kind": "cedar", "x": 340, "h": 50},
			{"kind": "stone_lantern", "x": 520}, {"kind": "rock", "x": 700, "s": 16}, {"kind": "rock", "x": 980, "s": 12},
			{"kind": "cedar", "x": 1120, "h": 60}, {"kind": "torii", "x": 1250, "h": 44},
		],
	},
	"mountain_trail": {
		"name": "the mountain pass",
		"width": 1100,
		"backdrop": "peaks",
		"ground": "stone",
		"slope": [[0, 0], [300, 30], [600, 45], [1100, 100]],
		"camp": {"x": 480, "w": 420, "look": "ruined way station"},
		"forage": {"a": 300, "b": 420},
		"foes": {"tengu": 2, "onibi": 2, "gaki": 2},
		"props": [
			{"kind": "torii", "x": 90, "h": 44}, {"kind": "waterfall", "x": 220, "h": 80}, {"kind": "stone_lantern", "x": 300},
			{"kind": "rock", "x": 420, "s": 10}, {"kind": "cedar", "x": 560, "h": 54}, {"kind": "rock", "x": 690, "s": 16},
			{"kind": "stone_lantern", "x": 800}, {"kind": "rock", "x": 930, "s": 11}, {"kind": "torii", "x": 1040, "h": 44},
		],
	},
}

const PEAK := {
	"name": "the mountain temple",
	"width": 900,
	"backdrop": "peaks",
	"ground": "stone",
	"slope": [[0, 0], [120, 10], [600, 120], [900, 125]],
	"buildings": [
		{"id": "temple", "name": "the temple of the peak", "x": 650, "w": 210, "h": 112, "kind": "temple", "pay": 0, "loot": 0},
	],
	"props": [
		{"kind": "cedar", "x": 30, "h": 80}, {"kind": "waterfall", "x": 85, "h": 64}, {"kind": "torii", "x": 150, "h": 56}, {"kind": "stone_lantern", "x": 200},
		{"kind": "cedar", "x": 260, "h": 90}, {"kind": "torii", "x": 340, "h": 60}, {"kind": "stone_lantern", "x": 400},
		{"kind": "cedar", "x": 470, "h": 86}, {"kind": "torii", "x": 540, "h": 64}, {"kind": "stone_lantern", "x": 610},
		{"kind": "stone_lantern", "x": 880},
	],
}

const DEFS := {
	"village": {
		"start": {"area": "street", "x": 140.0, "y": 228.0},
		"end": {"area": "riverbank", "x": 870.0, "y": 228.0},
		"alms": {"building": "house", "giver": "Oume"},
		"patrols": 1,
		"fire_spread": 0.12,
		"fire_gap": 45,
		"hunter_scale": 1.0,
		"areas": {
			"street": {
				"name": "the village street",
				"width": 1000,
				"backdrop": "hills",
				"ground": "earth",
				"exits": {"right": "riverbank"},
				"doors": [{"x": 172, "w": 56, "dir": "up", "to": "lane", "at": 350}],
				"buildings": [
					{"id": "house", "name": "Oume's house", "x": 60, "w": 110, "h": 62, "kind": "house", "pay": 3, "loot": 3, "pantry": 2},
					{"id": "stall", "name": "the food stall", "x": 230, "w": 80, "h": 48, "kind": "stall", "pay": 3, "loot": 2, "pantry": 3},
					{"id": "inn", "name": "the inn", "x": 380, "w": 140, "h": 80, "kind": "inn", "pay": 4, "loot": 4, "pantry": 1, "barrels": 3,
						"style": {"roof": "thatch", "roof_col": "#6f5f40", "storeys": 1, "lanterns": 1}},
					{"id": "carp", "name": "the carpenter's house", "x": 590, "w": 100, "h": 60, "kind": "house", "pay": 3, "loot": 3, "pantry": 2,
						"style": {"roof": "bark", "roof_col": "#5a4a36"}},
					{"id": "shrine", "name": "the shrine", "x": 790, "w": 100, "h": 74, "kind": "shrine", "pay": 0, "loot": 1},
				],
				"props": [{"kind": "cedar", "x": 920, "h": 74}, {"kind": "cedar", "x": 960, "h": 64}],
				"hides": [
					{"x": 172, "w": 56, "max_scale": 1.6, "look": "alley"},
					{"x": 524, "w": 64, "max_scale": 1.8, "look": "alley"},
					{"x": 900, "w": 90, "max_scale": 2.4, "look": "grove"},
				],
				"npcs": [
					{"building": "house", "dx": 124, "face": -1, "robe": "#6d5a78", "skin": "#d9b595"},
					{"building": "stall", "dx": 40, "face": 1, "robe": "#8c4b2f", "sash": "#d9cfb4"},
					{"building": "inn", "dx": 92, "face": -1, "robe": "#3f4f47"},
					{"building": "carp", "dx": -10, "face": 1, "robe": "#5b4a38", "hat": "#7b6a48"},
				],
			},
			"lane": {
				"name": "the back lane",
				"width": 700,
				"backdrop": "hills",
				"ground": "earth",
				"doors": [{"x": 320, "w": 60, "dir": "down", "to": "street", "at": 200},
					{"x": 526, "w": 32, "dir": "up", "to": "temple_path", "at": 125}],
				"buildings": [
					{"id": "kura", "name": "the village storehouse", "x": 40, "w": 100, "h": 70, "kind": "house", "pay": 3, "loot": 2, "pantry": 4,
						"style": {"wall": "#e6e0d0", "roof": "tile", "roof_col": "#3a3c44"}},
					{"id": "widow", "name": "the widow's hut", "x": 430, "w": 90, "h": 52, "kind": "house", "pay": 2, "loot": 1, "pantry": 1,
						"style": {"roof": "thatch", "roof_col": "#6a5c3e", "wall": "#7a5a40"}},
				],
				"well": {"x": 240},
				"forage": {"a": 560, "b": 690},
				"props": [{"kind": "cedar", "x": 620, "h": 70}],
				"hides": [
					{"x": 150, "w": 60, "max_scale": 2.0, "look": "cargo"},
					{"x": 600, "w": 80, "max_scale": 2.4, "look": "grove"},
				],
				"npcs": [
					{"building": "widow", "dx": 100, "face": -1, "robe": "#4f4a5a", "skin": "#d9b595"},
				],
			},
			"temple_path": {
				"name": "the temple path",
				"width": 800,
				"backdrop": "forest",
				"ground": "earth",
				"doors": [{"x": 100, "w": 50, "dir": "down", "to": "lane", "at": 540}],
				"buildings": [
					{"id": "temple", "name": "the village temple", "x": 230, "w": 150, "h": 90, "kind": "shrine", "pay": 0, "loot": 2,
						"style": {"roof": "tile", "roof_col": "#3a3c44"}},
					{"id": "charcoal", "name": "the charcoal burner's hut", "x": 470, "w": 90, "h": 54, "kind": "house", "pay": 2, "loot": 1, "pantry": 1,
						"style": {"roof": "bark", "roof_col": "#4f4434", "wall": "#5a4834"}},
				],
				"forage": {"a": 600, "b": 780},
				"props": [{"kind": "cedar", "x": 40, "h": 86}, {"kind": "stone_lantern", "x": 200}, {"kind": "stone_lantern", "x": 400},
					{"kind": "cedar", "x": 640, "h": 90}, {"kind": "cedar", "x": 740, "h": 80}],
				"hides": [
					{"x": 160, "w": 60, "max_scale": 2.0, "look": "grove"},
					{"x": 400, "w": 60, "max_scale": 1.8, "look": "grove"},
				],
				"npcs": [
					{"building": "temple", "dx": 160, "face": -1, "robe": "#2a2a30", "sash": "#d9a441"},
				],
			},
			"riverbank": {
				"name": "the riverbank",
				"width": 900,
				"backdrop": "hills",
				"ground": "earth",
				"exits": {"left": "street"},
				"buildings": [
					{"id": "hut", "name": "the fisherman's hut", "x": 40, "w": 90, "h": 54, "kind": "house", "pay": 2, "loot": 2, "pantry": 2,
						"style": {"roof": "bark", "roof_col": "#4f4434", "wall": "#7a5a40"}},
					{"id": "bridge", "name": "the bridge", "x": 260, "w": 120, "h": 10, "kind": "bridge", "pay": 2, "loot": 0},
				],
				"river": {"a": 260, "b": 380},
				"forage": {"a": 460, "b": 860},
				"hides": [
					{"x": 180, "w": 70, "max_scale": 2.2, "look": "reeds"},
					{"x": 620, "w": 80, "max_scale": 2.0, "look": "grove"},
				],
				"npcs": [
					{"building": "hut", "dx": 104, "face": -1, "robe": "#4a5a6a", "hat": "#7b6a48"},
				],
			},
		},
	},
	"post_town": {
		"start": {"area": "street", "x": 20.0, "y": 228.0},
		"end": {"area": "checkpoint", "x": 870.0, "y": 228.0},
		"alms": {"building": "inn_b", "giver": "the Matsuya's mistress"},
		"patrols": 2,
		"fire_spread": 0.3,
		"fire_gap": 60,
		"hunter_scale": 1.3,
		"areas": {
			"street": {
				"name": "the post town street",
				"width": 1000,
				"backdrop": "hills",
				"ground": "earth",
				"exits": {"right": "checkpoint"},
				"doors": [{"x": 602, "w": 26, "dir": "up", "to": "backstreet", "at": 380}],
				"buildings": [
					{"id": "inn_a", "name": "the Kikyo inn", "x": 30, "w": 140, "h": 92, "kind": "inn", "pay": 4, "loot": 4, "pantry": 1, "barrels": 3,
						"style": {"noren": "#5a2d6b", "sign": "inn"}},
					{"id": "tea", "name": "the teahouse", "x": 200, "w": 90, "h": 56, "kind": "stall", "pay": 3, "loot": 2, "pantry": 3,
						"style": {"roof": "tile", "roof_col": "#4a4c55", "awning": "#a8322a", "lanterns": 2}},
					{"id": "den", "name": "the gambling den", "x": 320, "w": 100, "h": 64, "kind": "den", "pay": 3, "loot": 5},
					{"id": "inn_b", "name": "the Matsuya inn", "x": 450, "w": 150, "h": 96, "kind": "inn", "pay": 4, "loot": 4, "pantry": 2, "barrels": 4,
						"style": {"noren": "#2d3d6b", "lanterns": 3, "sign": "inn"}},
					{"id": "row", "name": "the row houses", "x": 630, "w": 150, "h": 70, "kind": "house", "pay": 3, "loot": 3, "pantry": 3,
						"style": {"roof": "tile", "roof_col": "#45474f", "storeys": 2, "wall": "#7d5a42"}},
				],
				"hides": [
					{"x": 172, "w": 26, "max_scale": 1.5, "look": "alley"},
					{"x": 602, "w": 26, "max_scale": 1.6, "look": "alley"},
					{"x": 810, "w": 110, "max_scale": 2.0, "look": "cargo"},
				],
				"npcs": [
					{"building": "tea", "dx": 45, "face": 1, "robe": "#7a3f52", "sash": "#e3c76a"},
					{"building": "den", "dx": 104, "face": -1, "robe": "#2f2f3a"},
					{"building": "inn_b", "dx": 160, "face": -1, "robe": "#3f4f47", "sash": "#2d3d6b"},
					{"building": "row", "dx": 60, "face": 1, "robe": "#6b5a3a", "hat": "#3a3226"},
				],
			},
			"backstreet": {
				"name": "the back street",
				"width": 800,
				"backdrop": "hills",
				"ground": "earth",
				"doors": [{"x": 350, "w": 60, "dir": "down", "to": "street", "at": 615}],
				"exits": {"right": "stables"},
				"buildings": [
					{"id": "ricestore", "name": "the rice merchant's storehouse", "x": 30, "w": 130, "h": 80, "kind": "house", "pay": 4, "loot": 3, "pantry": 5,
						"style": {"wall": "#e6e0d0", "roof": "tile", "roof_col": "#3a3c44", "storeys": 2}},
					{"id": "bath", "name": "the bathhouse", "x": 480, "w": 140, "h": 76, "kind": "house", "pay": 4, "loot": 3, "pantry": 0,
						"style": {"roof": "tile", "roof_col": "#4a4c55", "noren": "#2f6b6b", "lanterns": 2, "lantern_col": "#e8e0c8"}},
					{"id": "pawn", "name": "the pawnbroker's", "x": 650, "w": 100, "h": 60, "kind": "house", "pay": 3, "loot": 6, "pantry": 1,
						"style": {"roof": "tile", "roof_col": "#45474f", "noren": "#6b4a2b", "sign": "pawn"}},
				],
				"well": {"x": 250},
				"hides": [
					{"x": 170, "w": 50, "max_scale": 1.7, "look": "cargo"},
					{"x": 760, "w": 36, "max_scale": 1.5, "look": "alley"},
				],
				"npcs": [
					{"building": "bath", "dx": 150, "face": -1, "robe": "#2f6b6b"},
					{"building": "pawn", "dx": -12, "face": 1, "robe": "#3a3226", "hat": "#1b1b22"},
				],
			},
			"stables": {
				"name": "the stable yard",
				"width": 800,
				"backdrop": "hills",
				"ground": "earth",
				"exits": {"left": "backstreet"},
				"buildings": [
					{"id": "stable", "name": "the post stables", "x": 60, "w": 170, "h": 66, "kind": "house", "pay": 3, "loot": 1, "pantry": 2,
						"style": {"roof": "thatch", "roof_col": "#6f5f40", "wall": "#7a5a40"}},
					{"id": "sakeya", "name": "the sake wholesaler's", "x": 300, "w": 130, "h": 80, "kind": "house", "pay": 4, "loot": 4, "pantry": 0, "barrels": 5,
						"style": {"wall": "#e6e0d0", "roof": "tile", "roof_col": "#3a3c44", "sign": "sake"}},
					{"id": "kichin", "name": "the cheap lodging", "x": 520, "w": 120, "h": 60, "kind": "inn", "pay": 3, "loot": 2, "pantry": 1, "barrels": 1,
						"style": {"roof": "bark", "roof_col": "#4f4434", "lanterns": 1}},
				],
				"well": {"x": 720},
				"hides": [
					{"x": 240, "w": 50, "max_scale": 2.2, "look": "hay"},
					{"x": 650, "w": 40, "max_scale": 1.8, "look": "cargo"},
				],
				"npcs": [
					{"building": "stable", "dx": 180, "face": -1, "robe": "#5b4a38", "hat": "#7b6a48"},
					{"building": "kichin", "dx": -12, "face": 1, "robe": "#4a5a6a"},
				],
			},
			"checkpoint": {
				"name": "the checkpoint road",
				"width": 900,
				"backdrop": "hills",
				"ground": "earth",
				"exits": {"left": "street"},
				"buildings": [
					{"id": "gate", "name": "the checkpoint", "x": 90, "w": 44, "h": 70, "kind": "gate", "pay": 2, "loot": 2},
					{"id": "shrine", "name": "the roadside shrine", "x": 240, "w": 100, "h": 74, "kind": "shrine", "pay": 0, "loot": 1},
					{"id": "farm", "name": "the farmhouse", "x": 430, "w": 110, "h": 62, "kind": "house", "pay": 3, "loot": 2, "pantry": 3},
				],
				"forage": {"a": 600, "b": 860},
				"props": [{"kind": "stone_lantern", "x": 225}, {"kind": "stone_lantern", "x": 355}],
				"hides": [
					{"x": 350, "w": 60, "max_scale": 2.2, "look": "grove"},
					{"x": 550, "w": 40, "max_scale": 1.8, "look": "hay"},
				],
				"npcs": [
					{"building": "gate", "dx": -12, "face": -1, "robe": "#2e3f63", "hat": "#3a3226", "item": "spear"},
					{"building": "gate", "dx": 56, "face": -1, "robe": "#e9e3d3", "hat": "#1b1b22", "sash": "#a8322a", "item": "talisman"},
					{"building": "farm", "dx": 118, "face": -1, "robe": "#5b4a38", "hat": "#7b6a48"},
				],
			},
		},
	},
	"river_crossing": {
		"start": {"area": "landing", "x": 30.0, "y": 228.0},
		"end": {"area": "far_bank", "x": 770.0, "y": 228.0},
		"alms": {"building": "ferryhouse", "giver": "Ohatsu"},
		"patrols": 1,
		"fire_spread": 0.15,
		"fire_gap": 50,
		"hunter_scale": 1.0,
		"areas": {
			"landing": {
				"name": "the ferry landing",
				"width": 1150,
				"backdrop": "hills",
				"ground": "earth",
				"exits": {"right": "far_bank"},
				"buildings": [
					{"id": "inn", "name": "the boatmen's inn", "x": 40, "w": 140, "h": 80, "kind": "inn", "pay": 4, "loot": 4, "pantry": 2, "barrels": 3,
						"style": {"roof": "bark", "roof_col": "#4f4434", "lanterns": 2}},
					{"id": "fish", "name": "the fish market", "x": 210, "w": 110, "h": 50, "kind": "stall", "pay": 3, "loot": 2, "pantry": 4,
						"style": {"awning": "#2f6b6b"}},
					{"id": "ferryhouse", "name": "the ferry house", "x": 360, "w": 100, "h": 58, "kind": "house", "pay": 3, "loot": 3, "pantry": 1,
						"style": {"roof": "thatch", "roof_col": "#6a5c3e", "wall": "#7a5a40"}},
					{"id": "sheds", "name": "the boat sheds", "x": 980, "w": 130, "h": 54, "kind": "house", "pay": 2, "loot": 1,
						"style": {"roof": "bark", "roof_col": "#4f4434", "wall": "#6a5040"}},
				],
				"river": {"a": 640, "b": 860},
				"ferry": {"fare": 3},
				"props": [{"kind": "cedar", "x": 560, "h": 64}],
				"hides": [
					{"x": 180, "w": 28, "max_scale": 1.5, "look": "alley"},
					{"x": 480, "w": 110, "max_scale": 2.4, "look": "reeds"},
					{"x": 880, "w": 80, "max_scale": 2.0, "look": "cargo"},
				],
				"npcs": [
					{"building": "fish", "dx": 55, "face": 1, "robe": "#2f6b6b", "sash": "#d9cfb4"},
					{"building": "ferryhouse", "dx": 110, "face": -1, "robe": "#7a4a5a", "skin": "#d9b595"},
					{"building": "inn", "dx": 150, "face": -1, "robe": "#4a5a6a", "hat": "#b39a56"},
				],
			},
			"far_bank": {
				"name": "the far bank",
				"far_side": true,
				"width": 800,
				"backdrop": "hills",
				"ground": "earth",
				"exits": {"left": "landing"},
				"buildings": [
					{"id": "shrine", "name": "the water shrine", "x": 120, "w": 100, "h": 74, "kind": "shrine", "pay": 0, "loot": 1},
					{"id": "tea", "name": "the riverside teahouse", "x": 300, "w": 90, "h": 54, "kind": "stall", "pay": 3, "loot": 2, "pantry": 2,
						"style": {"roof": "thatch", "roof_col": "#6a5c3e", "awning": "#a8322a", "lanterns": 1}},
				],
				"forage": {"a": 480, "b": 780},
				"well": {"x": 420},
				"hides": [{"x": 600, "w": 90, "max_scale": 2.4, "look": "grove"}],
				"npcs": [{"building": "tea", "dx": 100, "face": -1, "robe": "#6b5a3a"}],
			},
		},
	},
	"castle_town": {
		"start": {"area": "main", "x": 30.0, "y": 228.0},
		"end": {"area": "approach", "x": 770.0, "y": 228.0},
		"alms": {"building": "tenement", "giver": "Okiku"},
		"patrols": 3,
		"fire_spread": 0.25,
		"fire_gap": 55,
		"hunter_scale": 1.6,
		"areas": {
			"main": {
				"name": "the castle town high street",
				"width": 1300,
				"backdrop": "hills",
				"ground": "stone",
				"exits": {"right": "approach"},
				"doors": [
					{"x": 330, "w": 30, "dir": "up", "to": "back", "at": 120},
					{"x": 1040, "w": 30, "dir": "up", "to": "back", "at": 820},
				],
				"buildings": [
					{"id": "brewery", "name": "the sake brewery", "x": 30, "w": 170, "h": 88, "kind": "inn", "pay": 5, "loot": 5, "pantry": 1, "barrels": 6,
						"style": {"wall": "#e6e0d0", "roof": "tile", "roof_col": "#3a3c44", "storeys": 2, "noren": "#6b4a2b", "lanterns": 0, "sign": "sake"}},
					{"id": "noodles", "name": "the noodle stall", "x": 220, "w": 90, "h": 52, "kind": "stall", "pay": 3, "loot": 2, "pantry": 3,
						"style": {"roof": "tile", "roof_col": "#4a4c55", "awning": "#d9cfb4", "lanterns": 1}},
					{"id": "merchant", "name": "the cloth merchant's", "x": 380, "w": 160, "h": 96, "kind": "house", "pay": 5, "loot": 7, "pantry": 2,
						"style": {"roof": "tile", "roof_col": "#3a3c44", "storeys": 2, "noren": "#2d3d6b", "lanterns": 2, "sign": "cloth"}},
					{"id": "row", "name": "the townhouses", "x": 760, "w": 240, "h": 74, "kind": "house", "pay": 4, "loot": 4, "pantry": 3,
						"style": {"roof": "tile", "roof_col": "#45474f", "storeys": 2, "wall": "#7d5a42"}},
					{"id": "tea", "name": "the castle teahouse", "x": 1090, "w": 110, "h": 60, "kind": "stall", "pay": 3, "loot": 3, "pantry": 2,
						"style": {"roof": "tile", "roof_col": "#4a4c55", "awning": "#a8322a", "lanterns": 2}},
				],
				"props": [{"kind": "castle", "x": 900}],
				"blockers": [{"id": "samurai", "x": 640, "w": 30, "name": "the drunk samurai", "look": {"robe": "#3a2a4a", "sash": "#d9cfb4", "item": "swords"}}],
				"hides": [
					{"x": 200, "w": 20, "max_scale": 1.4, "look": "alley"},
					{"x": 1010, "w": 24, "max_scale": 1.5, "look": "alley"},
					{"x": 560, "w": 70, "max_scale": 2.0, "look": "cargo"},
				],
				"npcs": [
					{"building": "noodles", "dx": 45, "face": 1, "robe": "#8c4b2f"},
					{"building": "merchant", "dx": 170, "face": -1, "robe": "#2d3d6b", "sash": "#e3c76a"},
					{"building": "tea", "dx": 120, "face": -1, "robe": "#7a3f52"},
				],
			},
			"back": {
				"name": "the back alleys",
				"width": 950,
				"backdrop": "hills",
				"ground": "earth",
				"doors": [
					{"x": 100, "w": 50, "dir": "down", "to": "main", "at": 345},
					{"x": 800, "w": 50, "dir": "down", "to": "main", "at": 1055},
				],
				"exits": {"right": "merchants"},
				"buildings": [
					{"id": "pawn", "name": "the pawnbroker's", "x": 200, "w": 100, "h": 62, "kind": "house", "pay": 3, "loot": 6, "pantry": 1,
						"style": {"roof": "tile", "roof_col": "#45474f", "noren": "#6b4a2b", "sign": "pawn"}},
					{"id": "den", "name": "the gambling den", "x": 330, "w": 100, "h": 64, "kind": "den", "pay": 3, "loot": 6},
					{"id": "tenement", "name": "the tenement", "x": 560, "w": 180, "h": 64, "kind": "house", "pay": 3, "loot": 2, "pantry": 3,
						"style": {"roof": "bark", "roof_col": "#4f4434", "wall": "#6a5040"}},
				],
				"well": {"x": 480},
				"hides": [
					{"x": 160, "w": 36, "max_scale": 1.8, "look": "cargo"},
					{"x": 750, "w": 40, "max_scale": 1.6, "look": "alley"},
				],
				"npcs": [
					{"building": "den", "dx": 104, "face": -1, "robe": "#2f2f3a"},
					{"building": "tenement", "dx": 90, "face": 1, "robe": "#5b4a38", "skin": "#d9b595"},
				],
			},
			"merchants": {
				"name": "the merchants' quarter",
				"width": 850,
				"backdrop": "hills",
				"ground": "stone",
				"exits": {"left": "back"},
				"doors": [{"x": 575, "w": 50, "dir": "down", "to": "approach", "at": 355}],
				"buildings": [
					{"id": "rice", "name": "the rice dealer's", "x": 40, "w": 150, "h": 84, "kind": "house", "pay": 5, "loot": 6, "pantry": 5,
						"style": {"wall": "#e6e0d0", "roof": "tile", "roof_col": "#3a3c44", "storeys": 2, "noren": "#6b4a2b"}},
					{"id": "apothecary", "name": "the apothecary", "x": 230, "w": 110, "h": 66, "kind": "house", "pay": 4, "loot": 4, "pantry": 1,
						"style": {"roof": "tile", "roof_col": "#45474f", "noren": "#2f6b6b", "lanterns": 1}},
					{"id": "inari", "name": "the Inari shrine", "x": 400, "w": 90, "h": 70, "kind": "shrine", "pay": 0, "loot": 1},
					{"id": "lacquer", "name": "the lacquerware shop", "x": 660, "w": 140, "h": 72, "kind": "house", "pay": 4, "loot": 7, "pantry": 1,
						"style": {"roof": "tile", "roof_col": "#3a3c44", "noren": "#a8322a", "storeys": 2}},
				],
				"hides": [
					{"x": 195, "w": 30, "max_scale": 1.5, "look": "alley"},
					{"x": 500, "w": 60, "max_scale": 2.0, "look": "cargo"},
				],
				"npcs": [
					{"building": "rice", "dx": 160, "face": -1, "robe": "#3f4f47", "sash": "#e3c76a"},
					{"building": "lacquer", "dx": -12, "face": 1, "robe": "#7a3f52"},
				],
			},
			"approach": {
				"name": "the castle approach",
				"width": 800,
				"backdrop": "hills",
				"ground": "stone",
				"exits": {"left": "main"},
				"doors": [{"x": 330, "w": 50, "dir": "up", "to": "merchants", "at": 600}],
				"buildings": [
					{"id": "hachiman", "name": "the Hachiman shrine", "x": 120, "w": 110, "h": 80, "kind": "shrine", "pay": 0, "loot": 1},
					{"id": "guard", "name": "the guardhouse", "x": 420, "w": 120, "h": 70, "kind": "house", "pay": 4, "loot": 3, "pantry": 2,
						"style": {"wall": "#e6e0d0", "roof": "tile", "roof_col": "#3a3c44"}},
				],
				"props": [{"kind": "castle", "x": 620}, {"kind": "stone_lantern", "x": 100}, {"kind": "stone_lantern", "x": 250}],
				"forage": {"a": 600, "b": 780},
				"hides": [{"x": 260, "w": 60, "max_scale": 2.0, "look": "grove"}],
				"npcs": [{"building": "guard", "dx": -12, "face": 1, "robe": "#2e3f63", "hat": "#3a3226", "item": "spear"}],
			},
		},
	},
}


## The abandoned post town on the old road: nobody to see the oni and nothing
## for it to eat, but the yokai of the place walk its streets at night.
const RUINED := {
	"ruined_town": {
		"start": {"area": "street", "x": 20.0, "y": 228.0},
		"end": {"area": "temple", "x": 870.0, "y": 228.0},
		"people": false,
		"patrols": 0,
		"fire_spread": 0.2,
		"fire_gap": 50,
		"hunter_scale": 0.0,
		"areas": {
			"street": {
				"name": "the abandoned street",
				"width": 1000,
				"backdrop": "forest",
				"ground": "earth",
				"exits": {"right": "temple"},
				"buildings": [
					{"id": "inn", "name": "the empty inn", "x": 40, "w": 150, "h": 92, "kind": "inn", "pay": 0, "loot": 1, "hp": 35, "barrels": 1,
						"style": {"noren": "#4a4a4a", "lanterns": 0}},
					{"id": "teahouse", "name": "the fallen teahouse", "x": 230, "w": 90, "h": 56, "kind": "stall", "pay": 0, "loot": 0, "hp": 0},
					{"id": "houses", "name": "the shuttered houses", "x": 360, "w": 170, "h": 70, "kind": "house", "pay": 0, "loot": 1, "hp": 50, "pantry": 1,
						"style": {"roof": "bark", "roof_col": "#4f4434", "wall": "#5a4834"}},
					{"id": "kura", "name": "the burned storehouse", "x": 580, "w": 110, "h": 74, "kind": "house", "pay": 0, "loot": 0, "hp": 0},
					{"id": "shrine", "name": "the overgrown shrine", "x": 780, "w": 100, "h": 74, "kind": "shrine", "pay": 0, "loot": 0, "hp": 45},
				],
				"forage": {"a": 890, "b": 990},
				"props": [{"kind": "cedar", "x": 210, "h": 70}, {"kind": "cedar", "x": 720, "h": 84}, {"kind": "rock", "x": 540, "s": 10}],
				"hides": [
					{"x": 195, "w": 30, "max_scale": 1.6, "look": "alley"},
					{"x": 700, "w": 70, "max_scale": 2.4, "look": "grove"},
				],
				"yokai": {"gaki": 2, "kasa": 2},
			},
			"temple": {
				"name": "the ruined temple yard",
				"width": 900,
				"backdrop": "forest",
				"ground": "earth",
				"exits": {"left": "street"},
				"buildings": [
					{"id": "hall", "name": "the ruined temple hall", "x": 200, "w": 200, "h": 100, "kind": "shrine", "pay": 0, "loot": 2, "hp": 30,
						"style": {"roof": "tile", "roof_col": "#3a3c44"}},
					{"id": "bell", "name": "the bell tower", "x": 460, "w": 70, "h": 80, "kind": "house", "pay": 0, "loot": 0, "hp": 0},
					{"id": "quarters", "name": "the priests' quarters", "x": 590, "w": 130, "h": 64, "kind": "house", "pay": 0, "loot": 1, "hp": 40, "pantry": 1},
				],
				"well": {"x": 100},
				"forage": {"a": 760, "b": 880},
				"props": [{"kind": "stone_lantern", "x": 170}, {"kind": "stone_lantern", "x": 430}, {"kind": "cedar", "x": 820, "h": 92}],
				"hides": [{"x": 740, "w": 90, "max_scale": 2.6, "look": "grove"}],
				"yokai": {"onibi": 2, "kitsune": 1, "gaki": 1},
			},
		},
	},
}


static func def(id: String) -> Dictionary:
	return DEFS[id] if DEFS.has(id) else RUINED[id]

## Every road out of a station, forward along the route or back down it, but
## never up to the warded temple: [{"to", "trail"}].
static func roads(id: String) -> Array:
	var out: Array = []
	for to in ROUTE[id].next:
		if to != "peak":
			out.append({"to": to, "trail": ROUTE[id].trails[to]})
	for from in ROUTE:
		if ROUTE[from].next.has(id):
			out.append({"to": from, "trail": ROUTE[from].trails[id]})
	return out

## Where someone coming into station `id` arrives: from behind (the road
## along the route) or from ahead (walking back down it).
static func entry(id: String, from_ahead: bool) -> Dictionary:
	var d := def(id)
	return d.end if from_ahead else d.start

## Where a trail walked from `from` to `to` runs: [the station at its left
## end, the one at its right]. A trail runs left to right along the route.
static func ends(trail: String, from: String, to: String) -> Array:
	return [from, to] if ROUTE[from].get("trails", {}).get(to, "") == trail else [to, from]
