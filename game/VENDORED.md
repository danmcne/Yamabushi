# Vendored from Shikigami

This folder is the fighting engine of Shikigami (github.com/danmcne/shikigami,
v18.3, commit 9a57410), copied unchanged except that its menu (main.gd) is left
out, and four small changes (below). Yamabushi uses it for the final standoffs: the rite at the temple (the
yamabushi against his own oni) and the master exorcist's (the oni against
him, wherever he catches it in the hunt). Keep it unchanged here and refresh it from the Shikigami repository,
so the two games share one engine; Yamabushi's adaptations live in
scripts/duel_view.gd.

## The changes

`combat/fighter_definition.gd` has a `binds_any` flag (off by default) that
lets a fighter bind spirits of any kind. Shikigami holds that yokai bind only
humans and humans only yokai; Yamabushi's oni binds the yokai it fells on the
road and brings them to its standoffs, so `duel_view.gd` sets the flag on the
oni. Every Shikigami fighter behaves as before.

`combat/bout.gd` has an `air_passes` flag (off by default): a fighter in the
air is not pushed back by the other, so one can jump over the other and land
on its far side. Yamabushi's standoffs set it.

`views/bout_view.gd` has a static `winner_titles` (empty by default): when
set, the end of a bout names its winner ("YAMABUSHI WINS") instead of
"PLAYER 1 WINS". Yamabushi sets it for each standoff.

`combat/bout.gd` has a `no_double_ko` flag (off by default): when both
fighters fall in the same frame, whoever had more health as the frame began
(the first fighter on a tie) survives on 1 health, knocked down, so every
round has a winner. Yamabushi's standoffs set it.

Reapply all four after refreshing the engine.
