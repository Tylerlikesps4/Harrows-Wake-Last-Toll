# Devlog

## Day 0 - Sat 7 Nov 2026 (jam start, 9:10 PM EST)
- New repo and Godot 4.3 .NET project, CI builds Windows/Linux zips and an Android APK on every push.
- First playable greybox: the St. Agnes Orphanage built from an ASCII map (dormitory, refectory, kitchen, main hall, Matron's office, chapel, infirmary), first-person controller with flashlight, run/sneak and stamina, the bell rope, clapper and chapel key to find, a locked chapel and the great bell to ring (the win).
- The Bellman (C#): dormant until you take the first item, then wanders near you on a grid path ringing his hand bell (3D sound), investigates noises (running, pickups, the chapel door), chases on sight, searches where he lost you. Catches end the run; retry puts you straight back in.
- Heartbeat and a red panic shimmer by distance to him. Title, pause, note reader, death and win screens, escape timer. Touch controls for phones.
- Automated playthrough test (25 checks) runs in CI.
- Reused from Harrow's Wake (pre-made, credited): CC0 textures, Kenney props, CC0 sound effects, the PSX shaders and the prop/material helper (`lib.gd`). Everything else is new this week.
