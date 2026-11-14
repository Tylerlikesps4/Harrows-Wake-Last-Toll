# Devlog

## Day 0 - Sat 7 Nov 2026 (jam start, 9:10 PM EST)
- New repo and Godot 4.3 .NET project, CI builds Windows/Linux zips and an Android APK on every push.
- First playable greybox: the St. Agnes Orphanage built from an ASCII map (dormitory, refectory, kitchen, main hall, Matron's office, chapel, infirmary), first-person controller with flashlight, run/sneak and stamina, the bell rope, clapper and chapel key to find, a locked chapel and the great bell to ring (the win).
- The Bellman (C#): dormant until you take the first item, then wanders near you on a grid path ringing his hand bell (3D sound), investigates noises (running, pickups, the chapel door), chases on sight, searches where he lost you. Catches end the run; retry puts you straight back in.
- Heartbeat and a red panic shimmer by distance to him. Title, pause, note reader, death and win screens, escape timer. Touch controls for phones.
- Automated playthrough test (25 checks) runs in CI.
- Reused from Harrow's Wake (pre-made, credited): CC0 textures, Kenney props, CC0 sound effects, the PSX shaders and the prop/material helper (`lib.gd`). Everything else is new this week.

## Day 1 - Sun 8 Nov 2026
- **Browser build.** Every other entry in the jam plays in the browser, and Godot 4.3 can't export C# projects to the web, so the Bellman's AI moved from C# (`csharp/Bellman.cs`) to GDScript (`scripts/bellman.gd`), line for line with the same behaviour (all 25 day-0 checks still pass). The project is now plain Godot 4.3 with no .NET. CI uses the standard Godot 4.3 editor and export templates and adds a Web export (threads off, so itch.io needs no special headers): `LastToll-Web.zip`, with `index.html` at the zip root, is published next to the Windows/Linux zips and the APK.
- **Hiding.** Four wardrobes (dormitory, kitchen, Matron's office, infirmary) and the infirmary bed. Inside a wardrobe you peek out through the gap between its doors; under the bed the mattress fills the top of your view. Your torch stays covered while you hide.
- **He knows if he saw you.** If the Bellman is chasing you or can see you when you get in, he walks to that wardrobe and opens it. If he didn't, he can't see you in there.
- **Hold your breath** (Ctrl, or the BREATH button on phones). Breathe normally within a few metres of him for two seconds and he hears you. Holding your breath drains stamina; run out and you gasp, and he comes for the spot.
- **His bell tells you where he is and what he's doing.** It's muffled through walls (and a little inside a wardrobe), using a second low-passed copy of the bell crossfaded by line of sight, which also works with the web build's sample-based audio. Its tempo now has three speeds: slow while he wanders, quicker when he has heard something, frantic in a chase.
- Smoke test grows from 25 to 43 checks (hiding, unseen vs seen, breath, wall muffling, bell tempo). Screenshot tour adds the wardrobe, the peek view and under the bed.
- Reused from Harrow's Wake (pre-made, credited): the Kenney `bookcaseClosedDoors` model as the wardrobe. `bell_muffled.ogg` is a low-passed copy of the CC0 hand bell.

## Day 2 - Mon 9 Nov 2026 (performance night)
- **Browser lag on integrated graphics (reported from an i3 laptop).** Flashlight shadow is off on Web/mobile (it re-rendered the scene each frame). The one-piece floor and ceiling are now 4x4-cell chunks so each room light only touches nearby geometry. Item glint OmniLights replaced by emissive materials (one fewer light per item). max_lights_per_object capped at 4. Flicker lights cached in an array instead of walking the level every frame. Web is capped at 60 fps. F3 shows an FPS readout. The post pass already runs at the 320x240 viewport.
- Smoke test still 43/43. Level/props milestone not started tonight; perf had priority.

## Day 3 - Tue 10 Nov 2026 (bug-hunt night)
- **Bug:** in the browser, Esc releases the mouse lock without the game seeing the key, so the Bellman kept hunting while the cursor was free. Losing mouse capture on Web now pauses the game (click/Enter resumes and recaptures).
- Smoke 43/43. Scares, lore notes and the Bellman model are carried over to Wed.

## Day 4 - Wed 11 Nov 2026
- Pause menu now has volume (- / +) and mouse sensitivity ([ / ]). Smoke 44/44. Smoke run clean, no new bugs found in the check pass. Music, scares, Bellman model and lore notes carry over to Thu.

## Day 5 - Thu 12 Nov 2026 (look, scares, lore, music)
Bug-hunt pass first (smoke run, screenshot tour, read through the scripts):
- **Bug:** on the browser build, Esc frees the mouse and pauses, but clicking did nothing to resume (only Enter/Esc did), and the note reader also only closed with a key. A mouse click now resumes from pause and closes notes.
- **Bug:** tapping or clicking just as the Bellman caught you could instantly restart the run (or skip the win screen) before you read it. The death and win screens now ignore input for their first second.
- **Bug:** on phones, using the BREATH toggle in a hiding spot and then leaving left the toggle on, so you sprinted straight out. Leaving a hiding spot now clears it.
- **Too dark to read:** the halls were nearly black in the screenshot tour. Ambient light is up and the fog thinner. There is now a Brightness setting in the pause menu (B).
- Checked, no change needed: `LastToll-Web.zip` has `index.html` at its root and the export has threads off (no SharedArrayBuffer), items are all reachable, the Bellman can path to every item and into the chapel once opened, the touch buttons fit a 20:9 phone screen in the tour (new shot 12), and the BREATH button works.
- Each fix has a smoke check.

New tonight:
- **The Bellman has his real body.** The greybox is replaced with the animated CC0 mannequin (Quaternius, from Harrow's Wake) in a long coat, top hat, cracked porcelain mask and his hand bell. He idles with his bell, walks formally and jogs when he chases you. Reused code helper: `scripts/actor_model.gd` and `assets/models/mannequin.glb` from Harrow's Wake (pre-made, CC0 model, credited in CREDITS.md).
- **Four more lore notes** (a child's scratched warning in the dormitory, the night-watch roster in the refectory, the Matron's ledger, the infirmary chart), five in all; the win screen counts them.
- **Three scares:** a creak above you in the dormitory, the lights die for a few seconds when you first enter the refectory with something in your hands, and a far door slams across the hall once you have two items. Taking the key makes the great bell shiver on its own, far away.
- **Win screen stats:** time, notes found, times you hid, times he saw you.
- **Music:** an original music-box lullaby in A minor over a drone, wind and a far-off bell, made this week with numpy (`tools/music/last_toll_theme.py`, GPL-3.0-or-later). Plays on the title screen and again after you ring the bell.
- Smoke test grows from 44 to 63 checks.

## Day 6 - Fri 13 Nov 2026 (final)
- Final check pass: smoke test 63/63 clean, no new bugs found. No gameplay changes; this is the submission build.
