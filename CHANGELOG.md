# Changelog

## 0.15.1
- A beaten fighter kneels into seiza the moment its health runs out, stays
  kneeling while the winner may seal it, and falls when the bout is over.
  Before, Shikigami's dazed stance during the sealing window cut in and the
  kneeling started over: the stall and the flicker at a knockout.
- No double knockouts: if both fall in the same frame, the one who had more
  health stands on 1 (a fourth small flag in the vendored engine).
- A dialog after the talisman struggle no longer takes the struggle's last
  presses: I and Space wait out a second's grace (numbers work at once). And
  the choice I or Space would take is never one that breaks a vow.
- Running water is quieter; the town's tune has a soft drum knock in place
  of the kotsuzumi's rising "pon".

## 0.15.0
- Sound and music, synthesized on Shikigami's synthesizer: effects for every
  named event, placed left or right on screen; wind, water, insects and fire
  as near as they are; music by place and hour on the yo and hirajōshi
  scales, its stems layered in as tension rises (the oni's night as the town
  stirs, the master exorcist's as the oni weakens); Shikigami's sounds in the
  standoffs. Sound and music switches in the pause dialog. `--sounds=DIR`
  writes everything to WAV files.
- The end of a bout names its winner ("YAMABUSHI WINS", "ONI WINS",
  "EXORCIST WINS"), not a player number (a third small flag in the vendored
  engine, `winner_titles`).
- A knocked-out fighter sinks into seiza, bows, then falls.
- The oni grows more slowly from eating (0.08 a meal), and in the hunt shrinks
  back between meals toward its size at the fall.
- The oni's navel was drawn below its waist, a dark spot on the tiger skin's
  hem; it is on the belly now. Its gourd no longer peeks out from the far side.
- The temple's torii stand back from the path, as the others do.

## 0.14.5
- The torii on the temple approach stand set back from the path again, as in
  0.14.2. The street's projection runs depth straight down the screen and
  shrinks nothing with distance, so a gate across the road shows only its
  edge: drawn faithfully it is a blade, not a torii, and any other drawing
  breaks the projection.

## 0.14.4
- The torii across the temple approach turned the other way (the near pillar
  to the right, the far one up and to the left), each foot on the path where
  it stands, and spaced clear of the stone lanterns.

## 0.14.3
- A hidden oni is drawn in the shadow of its hiding place, not see-through.
- In the hunt a raided building is restocked a whole day after the raid,
  not at every turn of day and night; leaving the town does not reset it.
- The oni carries the sake gourd at its waist, on the road and in the
  standoffs. Monk and oni drink from the gourd on its side, as from a bottle
  (the oni fills it at the cask).
- In the standoffs either fighter can jump over the other and land on its far
  side (a second flag in the vendored engine, `air_passes`; see
  game/VENDORED.md).
- The master exorcist returns with 20% more health each time (was 30%); the
  hunters grow a fifth each day of the hunt (was a tenth).
- Townspeople never stand in a river: they are placed on the banks, turn back
  at the water, and fetch up on the bank when knocked toward it.
- The torii on the temple approach stand across the path, which climbs
  through them.

## 0.14.2
- The rite is open at any curse. The oni scales with it: above 40 it is
  quicker and plays sharper, up to three computer levels above the
  difficulty's own at full curse (past Hard, by sharpening Shikigami's table
  toward a ceiling).
- In the hunt the oni's health, blows and speed follow its size and body.
- The master exorcist brings shikigami, drawn afresh each time (one, then
  two), and returns quicker as well as tougher and sharper.
- Hunters grow a tenth each day of the hunt, as well as with rumour.
- In the hunt a fallen building stays a ruin, with nothing to eat or drink
  in it, for 2, 3 or 4 days by difficulty, then stands whole.
- One prayer a day at each shrine (a goma there as well is still allowed).
- A shikigami's long neck and flying head are its own, faded as the spirit
  is, not its summoner's.

## 0.14.1
- Dawn at full rumour is an inspection, not the end: the checkpoint's
  struggle against the talisman. Pass, and rumour drops to 60.
- A watchman raises the alarm (and the rumour) once a night, not again each
  time he loses the oni and finds it.
- Easy: a beaten oni is bound only at full rumour, and the oni pushes less
  against a talisman (the struggle scales with difficulty: x0.6, x1, x1.2).
- The hunt is saved at each turn of day and night, and continued there.
- In the hunt the oni enters a town by the side its road comes in.
- Against the master exorcist the hunting oni's health follows its size and
  body, no longer the curse, which is always full in the hunt.
- The master exorcist is fought in the very street or stretch of trail where
  he caught the oni.

## 0.14.0
- The hunt. When the monk fails, the oni keeps the body and roams the whole
  road, by day and by night, until it is brought down: the roads out of a
  town's open edges go back down the route or on along it, and a trail's two
  ends both lead into towns. Days are awake (people flee and scream, guards
  see without lanterns); hunger kills; rumour follows; more hunters come every
  phase; the towns rebuild. The master exorcist catches up after two days and
  two nights and is fought where he finds the oni; thrown off, he returns
  three phases later, tougher and sharper each time. The endings: sealed,
  bound, starved, or torn down by yokai. Nothing is saved during the hunt.
- River crossings are played out instead of jumped: the ferryman poles the
  monk over, or the monk poles a traveller over himself, or he wades waist-
  deep (knee-deep at the village ford). Nothing interrupts a crossing.
- Anyone standing in a river is cut off at the waterline by the river itself,
  repainted over them, instead of a translucent box; the bed shelves from the
  banks, so the oni sinks and rises as it wades in and out. The boat and the
  bridge take their place in depth.
- The oni's waist sits inside its tiger pelt, and the monk's jacket inside
  his hakama, from every side, on the road and in the standoffs: both torsos
  are built on ellipses that are narrower across than deep.

## 0.13.0
- One set of keys for the road and the standoffs: J is the staff (the heavy
  blow in the standoffs), I the light blow, L the ofuda, A+L the conch;
  guard stays J+L and spirit guard J+K+L. A line at the foot of the standoff
  lists the chords.
- The yamabushi's standoff kit is the road's: the ofuda replaces meditation
  (he has no heal), the conch the sutra palm. The ofuda flies as a paper
  talisman and the conch as sound waves, not boxes.
- In the standoffs the yamabushi's back turns to the viewer when a full
  stroke swings his chest past profile, and the far arm goes behind him.
- The yokai the oni binds stand with it in the standoffs: against the monk
  in the rite, with you in the fall. (One change to the vendored engine, a
  flag that lets a fighter bind any kind; see game/VENDORED.md.)
- On the road the conch is A+L, and its call carries to every side.
- Stamina is pace: no more collapsing. A starving monk crawls, and only dusk
  ends the day. A weak monk may set out from the map.
- The watch goes to look at what it hears ("?") and raises the alarm only
  if its lantern finds the oni.
- The run is saved at each dawn on the map; Continue on the title dialog.
- Gamepad on the road, mirroring the keys.
- Named events (strike, crash, roar, conch, fire, alarm, ...) for sound and
  music to follow.

## 0.12.0
- Pause: P or Esc (and a button on the touch pad).
- Hair covers the upper back of the head from every side, for the monk and
  the oni (a cap of the head's sphere, seen as it faces).
- In the standoffs the arms are drawn near and far as the upper body turns
  (Shikigami's own turn), so the shoulders no longer seem to cross; the head
  and chest follow the same turn.
- The monk's staff reaches the ground when held upright. The oni's kanabo
  rests on top of its shoulder, the fist closed over the grip.
- Walking toward or away from the viewer, the feet lift in turn.
- Drinking, smoking, the conch, and the oni's eating and drinking are done
  side-on, never hidden behind the head.
- The watch hears: a crash or a blow brings every watchman within earshot,
  far beyond the lanterns. A drunk oni is louder, staggers and is slower.
- Fire brings the town: patrols make for it, and townspeople with buckets
  put it out if left alone; any who see the oni scream.
- More streets: the village temple path, the post town's stable yard, the
  castle town's merchants' quarter (a second way round to the approach).
- A third road from the post town: the old road to an abandoned post town,
  with no people and no rumour, little food, and yokai in its streets at
  night, which the oni can fight and bind.
- The oni can walk off a trail's end at night into the town, and its night
  goes on there.

## 0.11.0
- The yamabushi and the oni can be seen from any side. Their rig is laid out
  in depth and projected for the way they face, its parts drawn far to near,
  so it turns as they walk: profile, three-quarters, front, back and the
  three-quarter back views. Standing after walking along the street they
  settle three-quarters toward the viewer. The monk prays facing the shrine
  and stands under the falls facing out; the oni roars at the viewer.
- Arms have elbows: a resting bend, and hands that reach (the gourd, the
  pipe and the conch to the mouth, palms together for gassho).
- The yamabushi: the jacket covers his shoulders; the staff's rings follow
  the staff however it is held.
- The oni: a short flared tiger-skin with a pointed hem; heavy bare feet
  that stand on the ground; the kanabo resting on its shoulder; arms lit and
  ringed in gold against a darker torso; a shaggy mane that frames the face
  from the front and covers the head from behind; brows, tusks.
- Nights on the trail: dusk or collapse on a trail is spent there, no longer
  carrying the monk to the next town. The oni fights the yokai of the camp
  and may bind them as its own shikigami, which answer it on the trails and
  in the streets (each adds to the curse). Trails have roots to forage.
- Hunger no longer ends the oni's night: a starving oni slows instead.
- The new moon: a night begun with none left, away from the temple, is the fall.
- The shikigami's specials are shared by the monk and the oni (demon fire is
  now a streak of flame down the way).

## 0.10.0
- One set of character sheets for every figure. On the road, a
  low-resolution rig jointed only at shoulder and hip: townspeople face you
  at rest and turn side-on to walk; the monk stands three-quarter and walks
  in profile. The yamabushi is drawn in more detail: tokin, suzukake jacket,
  baggy hakama to the knees (no gap between the thighs), dark kyahan and
  straw sandals, the yuigesa with its bonten, gourd, kiseru and horagai at
  his belt, and arms that swing the ringed staff. The oni has its mane,
  horns, tiger-skin loincloth and studded kanabo.
- The standoffs draw the same sheets over Shikigami's posed skeleton, which
  still traces every blow. The yamabushi in the rite is now the journey's
  yamabushi, not En no Gyoja's monk.
- The monk's acts are animated, and he stands still while they last: the
  pipe (smoke rising), the gourd at his lips, prayer kneeling in gassho.
- The conch: S+L on a trail stuns every demon within earshot.
- Takigyo under the waterfalls of the cedar trail, the mountain pass and the
  temple; goma fire rites before shrines or on the oni's ashes, with firewood
  gathered at foraging spots.
- The drunk samurai will take the sake from your gourd (a small lapse).
- The rite: meditation heals as it is held, so breaking it off stops the
  healing; the conch replaces the Sutra Palm, and a guard blunts it rather
  than stopping it.
- The oni shows what it does: eating, drinking, setting fires.
- The key legend widens to fit what it says.
- Checks: frame counts are held to real time, so a fast machine no longer
  fails the wading check.

## 0.9.0
- Back to the plain style for the journey: the simple, outline-free figures
  return for the monk, townspeople, the watch and the oni. Legs now step when
  people walk. The monk again strikes with his staff and carries his gourd at
  his hip.
- The standoffs keep Shikigami's puppets, which its hit tracing depends on,
  but drawn flat without outlines.
- More yokai on the trails: umbrella ghosts, fox spirits that blink behind you,
  and swooping tengu, each with its own shikigami special when bound, and a
  Shikigami spirit in the standoffs.
- The gourd: drinking says what it did (stamina before and after, sips left),
  and a full monk keeps his water rather than wasting it. Water gives 12.
- Fire: the oni sees a fire icon over a building it can light, and O sets it
  alight; the legend says when no building is in reach.
- A legend of the keys in the lower left, changing with what they do.

## 0.8.0
- One art style: every figure in the journey (monk, oni, townspeople, the
  watch, exorcists, hungry ghosts, kappa) is now a cut-paper puppet on
  Shikigami's rig, the same as in the standoffs. The monk is a yamabushi with
  his staff upright and his gourd; the oni is Shuten-doji's puppet; the kappa
  Kawataro's.
- The standoffs are staged in the mountain temple's courtyard under a
  moonless sky, drawn in the journey's style, instead of Shikigami's shore.
- Keys moved to Shikigami's diamond: J strike, I act (or Space), L special
  (ofuda by day, roar at night), K spirit, U gourd, O pipe.
- Dialog choices have number keys, and W/S and I work in dialogs too.

## 0.7.0
- The final standoffs run on the Shikigami engine (v18.3, vendored in game/):
  the rite (the yamabushi against his oni) and the fall (the oni against the
  master exorcist). Every way the road can end now leads to one of them. The
  run tilts both fighters without replacing their movesets; bound shikigami
  come as spirits.
- Difficulty levels: Easy, Normal, Hard, chosen at the start (nights to spare,
  heat, damage, capture, hunters, duel opponent).
- One body, fixed: the oni's strength is the monk's stamina on the same scale,
  hunger is a fixed 15 a night, meals give it back, and dawn hands over what
  is left. Before, hunger alone drained more than a whole body over a night,
  so even an oni that ate well woke the monk exhausted.
- A weak body walks slowly (continuously, not only below 20) and the oni
  slows too.
- The fork asks which road when you set out, and walking back undoes it.

## 0.6.0
- The road is longer and forks: the river crossing and the castle town are
  new, with the paddy road, castle road and high pass between them. Five
  nights for four stations; the high pass skips the river crossing.
- Trails and the temple climb actually climb: slopes, stone steps, slower and
  more tiring uphill, far ridges sinking as you rise.
- Taken from Shikigami: spirit binding and specials that recharge. Defeated
  demons leave spirits to free or bind; up to two shikigami, each with its own
  special; the monk's ofuda; the oni's roar. Cross-binding holds: only the
  human binds yokai, so shikigami are silent at night.
- Kappa on the paddy road, who bow back and spill their dish.
- The river crossing's ferry (pay, work or wade) and a far bank you must reach
  before leaving; the castle town's drunk samurai (speak or strike, or go round).
- Alms givers in the post town and the castle town.
- The moon now wanes toward the rite night and is absent on it, not on the
  last night before. Arriving at the temple early means waiting in its wards.
- Testing aid on F10. Travel costs 15 stamina; the trail costs the rest.
- README describes the current version only; this changelog holds history.

## 0.5.0
- Icons for the monk's actions and on places; towns as small networks of
  streets joined by alleys, with wells, storehouses, a bathhouse and a
  pawnbroker; raided stores raise heat when found; changing into the oni in
  the open may be seen; the staff swings toward where the monk faces.

## 0.4.0
- Drawing kit of styled, reusable parts; distinct town styles; trails with
  minor demons; the temple at the peak; moon phases; lantern light equals what
  a patrol sees; food and sake markers at night; floating Act prompt; dialogs
  wrap; version shown in game.

## 0.3.0
- Belt-scroll streets with connected areas; one body for monk and oni; travel
  costs stamina; night patrols; hiding; the river blocks all but the oni; a
  separate gourd button; input grace; fixed a double dusk.

## 0.2.0
- Godot port; top-down pilgrimage map; the post town and its checkpoint.

## 0.1.0
- HTML prototype: one village, five nights.
