# Yamabushi  v0.15.1

A mountain ascetic has sealed an oni inside his own body. He must walk the
pilgrimage road and reach the temple at the peak by the new moon, with his
curse low enough to face it in the rite that casts it out. By day he keeps or
breaks his vows; by night, unless the seal holds, you play the oni. Monk and
oni share one body: what the oni eats, the monk wakes fed by; whatever it
breaks stays broken. If the monk fails, the oni keeps the body and roams the
whole road, by day and by night, until the exorcists bring it down. Godot 4.4, 2D belt-scroller, drawn in plain flat shapes
without outlines. Every figure is drawn from one set of character sheets. On
the road the yamabushi and the oni stand on a low-resolution rig (shoulders
and elbows, legs jointed only at the hip) that can be seen from any side: they
turn as they walk, through profile, three-quarters, front and back, and a
pose can face somewhere (the monk prays with his back to you, facing the
shrine, and stands under the falls facing out). Townspeople keep a simpler
rig, facing you at rest and in profile as they walk. The final standoffs are
fought on the engine of Shikigami (vendored in game/), with the same sheets
drawn over the full skeleton Shikigami poses, because it traces each blow
from the posed weapon. Changes between versions are in CHANGELOG.md.

## Running

    godot --path .                # or open project.godot in the editor and press F5

P or Esc pauses (a dialog over everything; nothing moves under it). The keys
follow Shikigami's diamond, and mean the same on the road and in the
standoffs: I above, J left, L right, K below. J is always the staff (or the
kanabo), L the ofuda (or the roar), A+L the conch. In the standoffs either fighter can jump clean over the other. A knocked-out fighter sinks into seiza before it falls, and the end of a bout
names its winner. A gamepad mirrors the
diamond: X the staff, Y act, B the special, A the spirit, the shoulder
buttons the gourd and the pipe, Start to pause, the d-pad or left stick to
walk.

The run is saved at each dawn, on the map (in the hunt, at each turn of day
and night), and Continue on the title dialog takes it up there. There is one saved run; it is gone when the run
ends.

| Key | By day | On a trail | At night (the oni) |
| --- | --- | --- | --- |
| W A S D / arrows | walk, also in depth | walk | walk |
| I or Space | act (icons show what) | bind a spirit; bow to a kappa; forage | eat or drink; on a trail, bind a spirit for the oni |
| J | | strike with the staff; beside a spirit, free it | strike with the kanabo |
| L | | throw an ofuda (recharges); A+L sound the conch | roar (recharges) |
| K | | call a shikigami | call one of the oni's own |
| U | the gourd | the gourd | |
| O | the pipe (a small lapse) | the pipe | set a fire |
| F10 | testing aid: fights cost nothing | | |

A legend in the lower left shows what each of these keys does at that moment;
keys that do nothing are dimmed. In every dialog each choice has a number key; W/S or the arrows move between
choices and I, Space or Enter takes one. On touch screens an on-screen pad
appears; `-- --touch` forces it. In the standoffs: A D move, W jump, S
crouch, J the heavy blow (the staff, or the kanabo), I the light one, L the
special, away + L the second, K a spirit; J+L guard, J+K+L spirit guard, J+I
throw, and away, toward + K to seal a beaten opponent. A line at the foot of
the standoff lists the chords.

## Difficulty

Chosen when a run begins.

| | Easy | Normal | Hard |
| --- | --- | --- | --- |
| Nights before the new moon (four stations) | 6 | 5 | 4 |
| Rumour (heat) grows | x0.6 | x1 | x1.3 |
| Damage from the watch and from trail demons | x0.5 | x1 | x1.3 |
| Heat at which a beaten oni is bound | 100 | 80 | 70 |
| The oni's push against a talisman (checkpoint, dawn inspection) | x0.6 | x1 | x1.2 |
| Days a fallen building stays a ruin, in the hunt | 2 | 3 | 4 |
| Hunters who come | x0.7 | x1 | x1.3 |
| The duel opponent (Shikigami computer level) | Practice | Easy | Normal |

## The road

    mountain village --cedar trail--> post town --paddy road--> river crossing --castle road--> castle town --mountain pass--> temple
                                          |\--old road--> abandoned post town --castle road-->/|
                                          \______________ high pass (skips a station) ________/

There are five nights before the new moon on Normal: one for each of the four
stations, and one to spare. The rite is on the sixth, moonless, night. The
moon wanes visibly night by night. The high pass saves a night but is the
hardest trail; at the fork, setting out asks which road, and walking back to
the station lets you reconsider. The old road through the abandoned post
town takes as many nights as the river. Arriving at the temple early, the monk waits
inside its wards: the oni stays sealed, but the seal still weakens each night.

- **Mountain village**: street, back lane, the path up to the village
  temple, riverbank. Alms from Oume, a well, a storehouse, the bridge.
- **Post town**: street, back street, stable yard, checkpoint road. Inns, a
  gambling den, a bathhouse, a pawnbroker, a sake wholesaler; the checkpoint
  inspection (submit, and hold the oni down, or lie).
- **The abandoned post town** (on the old road): an empty street and a ruined
  temple yard, half fallen. Nobody lives there: no watch and no rumour, but
  almost nothing for the oni to eat, and at night the yokai of the place walk
  its streets. The oni can fight them and bind them for itself. By day there
  are roots, firewood, a well, ruins to repair or to light a goma on.
- **River crossing**: no bridge. The ferry costs three coins (the ferryman
  poles you over); poling it yourself pays your passage with three hours'
  work; wading, waist-deep, costs 20 stamina. You can only leave once you are
  on the far bank, so cross the day you arrive, or lose a night. The oni
  wades at night, and may leave you on the far side. Anyone in a river stands
  in it to the waist (the village ford, to the knees), deeper as the bed
  shelves from the bank.
- **Castle town**: high street, back alleys, merchants' quarter, castle
  approach (the alleys and the merchants' quarter make a second way round to
  the approach). A sake brewery,
  three night patrols, the castle on the skyline, and a drunk samurai blocking
  the high street. A calm word moves him if your heat and curse are low;
  knocking him down breaks a vow and draws heat; or go round by the alleys.
  With sake in the gourd you can offer it to him: a small lapse, and he lets
  you by whatever he suspects.
- **The temple**: stone steps climbing past torii, under a moonless sky.

Trails rise and fall: climbing is slower and more tiring.

## The monk's kit

Each act holds the monk in its pose for a moment, and he stands still while
it lasts.

- **Gourd (U).** Water: +12 stamina a sip, two sips a filling. After a night
  as the oni it holds sake; drinking that is +60 and a broken vow.
- **Pipe (O).** Half an hour, +5 stamina, +2 curse: a small lapse.
- **Conch (A+L on a trail).** The horagai's call stuns every demon within
  earshot for two seconds; it does not drive them off. Three stamina; twelve
  seconds to get the breath back.
- **Takigyo.** Under a waterfall (on the cedar trail, the mountain pass, and
  below the temple): an hour, 25 stamina, and the curse eases by 10. Once at
  each fall; not below 30 stamina.
- **Prayer.** Two hours and 10 stamina at a shrine, once a day at each: it
  weakens tonight's oni and eases the curse by 2.
- **Goma.** A fire rite, lit before a shrine or on the ashes of a house the
  oni burned, with a bundle of firewood gathered at a foraging spot (an
  hour). Three hours, begun by 15:00, once a day in each town. If rumour is
  below 50 the town comes: the curse eases by 12, rumour by 15, and they
  leave two coins; on ashes, a further 6 and 10. Otherwise you chant alone
  and the curse eases by 6.

## Spirits and shikigami

Minor demons gather at a camp on each trail: hungry ghosts (gaki) and
umbrella ghosts (kasa-obake) in the cedar forest, kappa by the paddies, fox
spirits (kitsune) that blink out and reappear behind you on the castle road,
crow-headed tengu swooping on the passes, and demon fire (onibi). The monk fights with his staff and his own
special, a thrown ofuda that stuns and recharges. Bowing to a kappa makes it
bow back and spill the water in its head-dish, after which it takes double
damage.

A defeated demon leaves its spirit for a few moments. Strike it to free it, a
small merit; or press Act to bind it as a shikigami, as En no Gyoja bound his
two oni. Two can be held. A shikigami answers its call with its own special and then
recovers (K): the hungry ghost seizes a demon and will not let go, demon fire
streaks down the path burning all it passes, the kappa empties a river over
everything near, the tengu's gale blows everything ahead back, the fox steps
you behind the nearest demon to strike, and the umbrella ghost opens over you
so that blows land at half strength for a while. Each binder commands only
its own: the monk's shikigami are silent at night. L is the oni's own roar,
which throws back and stuns the watch but is heard far down the street.

## Nights on the trail

When dusk falls on a trail, the night is spent where the monk is. If the seal holds he sleeps by
the path (+30 stamina). If not, the oni wakes among the yokai, who come out
for it: it fights them with the kanabo (J) and its roar (L), and beside a
fallen yokai's spirit it may bind it for itself (I). The oni's shikigami
answer only the oni (K at night, on the trails and in the streets), two at a
time, and each one adds 3 to the curse. They stand with it in the standoffs,
against the monk in the rite and beside you against the master exorcist (Shikigami holds
that yokai bind only humans; Yamabushi's copy of the engine lets its oni bind
anything: see game/VENDORED.md). At dawn
the monk wakes where the oni ended the night, as strong as it left the body.
Walking off the trail's end at night, the oni goes on down into the town, and
spends the rest of the night there (the temple's wards turn it back from the
peak).
Every trail has a stretch where roots can be dug (I, twice a day: +15
stamina, an hour and a half), so a starving monk can still reach the next
town without breaking a vow; the sake in the gourd is the quicker way.

## The final standoffs

Every road ends in a fight on the Shikigami engine.

- **The rite.** At the temple, whatever the curse, the yamabushi faces his
  own oni (Shuten-doji's kit: Sake, Kanabo Quake). Win, and finish
  it with the sealing rite if you can, and the oni is cast out. The yamabushi
  is built in Yamabushi on En no Gyoja's kit with the road's own specials: the
  ofuda (L), thrown straight, and the conch (away + L), a call that stuns long
  and hurts little, which a guard blunts but does not stop (the guarding
  fighter takes half its damage and half its stun; it cannot finish anyone by
  itself). He has no heal.
- **The master exorcist.** If the monk fails, the oni takes the body (see
  the hunt, below) and the master exorcist (Abe no Seimei's kit) comes after
  it. You play the oni wherever he catches it.

The rite is staged in the courtyard of the mountain temple under the moonless
sky; the master exorcist is fought in the street or on the stretch of trail
where he caught the oni, its buildings as damaged as the oni left them.

Both fighters keep their full base movesets; the run only tilts them. In the
rite the oni's health grows with the curse and with what it ate, and above a
curse of 40 it moves quicker and plays sharper (at full curse, three of
Shikigami's computer levels above the difficulty's own). In the hunt, where
the curse is always full, its health, blows and speed follow its size and
what is left of its body. Its blows grow with what it smashed; drinking makes
its sake heal more and sooner, arson its quake. The
monk's health follows his stamina on arrival and the spirits he freed. The
shikigami he bound come with him as spirits: the kappa as Kawataro's water
jet, the tengu as Sojobo's gale fan, the fox as Tamamo-no-Mae's fox step,
demon fire as her bewitching dust, the hungry ghost as the rokurokubi, the
umbrella ghost as the tanuki.

## The hunt

The monk fails if the rite is lost, the curse reaches 100 on the road, or
the new moon passes. Then the oni has the
body for good, and the yamabushi is gone. It starts where he fell (from the
temple, at the top of the mountain trail, the wards driving it down) and can
walk the whole road, both ways: every street edge that leads nowhere in town
opens the roads out of it, back down the route or on along it, and each
trail's two ends lead down into the towns there, entering each by the side
its road comes in. Only the temple stays shut.

- Day and night alternate, 45 seconds each. By night the town is as before.
  By day it is awake: its people are in the street, and run screaming from
  the oni (heat); its guards see far ahead of them without lanterns.
- Hunger kills. There is no monk to wake: a body that reaches nothing is the
  end. Food is in the towns, nowhere on the trails.
- Rumour does not stay behind on the road. The hunters grow with it and with
  every day the hunt goes on (a fifth more each day), exorcists among them
  more and more. Beaten in a town, the oni is bound.
- The towns rebuild. Every phase a damaged building regains 15. A building
  the oni raided is restocked a whole day (two phases) after the raid, not
  before. A fallen building stays a ruin, with nothing in it to
  eat or drink, for days (2 on Easy, 3 on Normal, 4 on Hard), and then stands
  whole: an oni that levels a town has to move on. The abandoned town stays
  as it is.
- The master exorcist catches up after two days and two nights, in whatever
  town the oni is in or next enters, and you fight him where you are. The
  oni comes to the fight as big as its meals made it and as strong as the
  road left it. He brings a shikigami, drawn afresh each time from the yokai
  of the roster, and two once he has been thrown off. Throw him off and the
  hunt goes on, but he is back three phases later: each time with 20% more
  health, 8% quicker on his feet, and playing a level sharper (past Hard, half
  the remaining way to a ceiling each time). If he wins, the oni is sealed.

The bottom right shows how far behind him the master exorcist is.

## Sound and music

All synthesized, like Shikigami's, from whose synthesizer it is built
(game/audio/sound.gd, unchanged; scripts/sounds.gd adds the road's sounds).
Nothing recorded ships, and there are no voices: a town that sees the oni
rings its fire bell and the watch beats its clappers.

- **Effects** follow the game's named events, each heard to the left or
  right where it happened on screen: the staff's knock and the jingle of its
  rings, the kanabo's thump and clank, splitting wood and collapsing
  buildings, a fire catching, the watch's clappers (once for "?", faster and
  faster for the alarm), the oni's roar, a temple bell sagging as the seal
  gives way and a far bell at dawn, gulps, chomps and the pipe's puff, the
  conch, the ofuda's flick, a shikigami's rustle and small bells, the bowl
  gong of prayer and binding, a chime for a freed spirit, the goma.
- **Ambience**: wind (strongest on the mountain), running water as near as
  the river or falls are, insects in the dark, crackling as near as a fire.
- **Music**, on Japanese pentatonic scales: the bright yo by day, the dark
  hirajōshi by night. The title and the map have Shikigami's slow tune; a
  town by day koto, a soft drum knock and shakuhachi; a trail a drone, a few koto
  notes and the shakuhachi. The oni's night is a drone and slow taiko, with
  the shamisen coming in when the town stirs (a watchman goes to look, or
  rumour runs high) and driving taiko and the noh flute when the watch is out
  after it; in the hunt it never quite settles, and rises as the master
  exorcist closes in. The rite is fought to Shikigami's fight tune; the master
  exorcist to his own, its noh flute and kotsuzumi coming in as the oni
  weakens. Endings close on a bell (the oni cast out) or a gong.
- **The standoffs** have Shikigami's sounds: a bell as each round begins,
  hits light and heavy, the knock of a block, the gong at a knockout.

Sound and music can each be turned off in the pause dialog. The tunes are
made in the background as the game starts (about a second each).

## Rules worth knowing

- Stamina is pace, not a cliff: below 40 the monk slows, down to a crawl at
  nothing, but hunger never stops him. Only dusk ends a day.
- Monk and oni share one body on one scale. The oni starts the night with the
  monk's stamina; hunger takes 15 over a night; each meal gives back 18 (a
  cask 12); the watch's blows come out of the same body. Whatever is left at
  dawn is the monk's stamina. A weak body walks slowly by day; by night a
  starving oni is not ended by hunger, but slows to a third of its pace, and
  falls sooner to the watch.
- The new moon is the night after the last: a night that begins with none
  left, anywhere but the temple, is the fall: the hunt begins.
- Every town has night watchmen; a patrol sees exactly what its lantern
  lights, but hears much farther: at a crash or a blow (a building or a person
  struck) every watchman within earshot goes to look ("?"), and raises the
  alarm ("!") only if his lantern finds the oni. A drunk oni is louder
  (heard from half as far again, its footsteps too), staggers, and is slower.
  The oni can hide in alleys, groves, reeds and cargo while it fits; hidden,
  it is drawn in their shadow.
- A fire is seen from every street: the patrols make for it, and townspeople
  come running with buckets. Enough of them, left alone, put it out; any who
  see the oni there scream, and rumour grows.
- Changing into the oni in the open may be seen. Raided stores are found at
  dawn. Both raise heat. Each watchman raises the alarm once a night, however
  often he loses the oni and finds it again.
- At full rumour (100) the exorcists are waiting at dawn and inspect the
  monk, as at the checkpoint: hold the oni down while the talisman burns and
  rumour drops to 60; fail and you are taken.
- A broken bridge stops the monk and the hunters; the oni wades.

## Structure

    scripts/game_state.gd    autoload: meters, the clock and moon, flags, bound
                             shikigami, the oni's behaviour record, station damage
    scripts/stations.gd      the road, stations, trails and the peak (data only)
    scripts/kit.gd           drawing kit: terrain, buildings, creatures, props
                             and icons, composed from reusable parts
    scripts/figure.gd        the character sheets: the yamabushi, the oni and
                             townspeople on the road's low-resolution rig
    scripts/duel_figures.gd  the same sheets drawn over Shikigami's posed skeleton
    scripts/monk_acts.gd     the monk's kit by day: gourd, pipe, conch, takigyo
    scripts/spirits.gd       the shikigami's specials, whoever calls them
    scripts/key_legend.gd    the on-screen legend of what the keys do now
    scripts/station_view.gd  belt-scroll town: the monk's day and the oni's night
    scripts/trail_view.gd    trails: slopes, demons, spirits and shikigami
    scripts/peak_view.gd     the climb to the temple and the rite
    scripts/map_view.gd      the pilgrimage map, with forks
    scripts/suppression.gd   the checkpoint struggle
    scripts/duel_view.gd     the final standoffs, on the Shikigami engine
    scripts/sounds.gd        the synthesized sounds, ambience and music
    scripts/audio.gd         autoload: what is heard, from the game's events and views
    scripts/main.gd          view switching, dialogs, toasts, endings, difficulty, testing aid
    game/                    the Shikigami fighting engine, vendored with four small changes (see game/VENDORED.md)
    scripts/touch_pad.gd     on-screen pad

## Checks (opt-in; the game never runs them by default)

    godot --headless --path . --fixed-fps 60 -- --checks
    godot --headless --path . --fixed-fps 60 -- --bot --bot-policy=virtue --bot-runs=2
    godot --headless --path . --fixed-fps 60 -- --bot --bot-policy=feed --bot-runs=2 --bot-noprayer
    godot --headless --path . --fixed-fps 60 -- --bot --bot-policy=random --bot-runs=8
    godot --headless --path . --fixed-fps 60 -- --bot --bot-policy=feed --bot-noprayer --bot-hunt --bot-runs=2
    godot --headless --path . --fixed-fps 60 -- --duel [--duel-hunt]   # computer on both sides
    godot --path . --fixed-fps 60 -- --snap=/tmp/shots     # needs a display
    godot --path . -- --figures=/tmp/figures               # every pose on one sheet; needs a display
    godot --headless --path . -- --sounds=/tmp/sounds        # every sound and tune as WAV files, with levels

If a fresh checkout reports missing classes when run from the command line,
open it once in the editor or run `godot --headless --path . --import`.

`--checks` drives the real game through one hundred and sixty-six rule checks. Bots take
`--bot-level=0|1|2` for the difficulty. The bots play
whole runs; they show the code runs and which paths are reachable, not how
the game feels. Tools run silent; `--with-sound` lets a bot play with sound
on, to show it keeps up with real play. With `--bot-hunt` a fall is played on through the hunt (the
computer fights the master exorcist) instead of starting again.

## Roadmap

- 1.0  Balance across the whole road at each difficulty, by playing it.
