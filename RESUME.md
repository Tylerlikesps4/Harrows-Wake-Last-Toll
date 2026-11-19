# build-9 resume notes
Godot 4.3 arm64 binary: /workspace/work/godot (templates in ~/.local/share/godot/export_templates/4.3.stable).
Smoke: `godot --headless -- --smoke` (63 PASS baseline).
- [x] 1 Bell pickup crash: guarded freed nodes, double pickup, timers after scene reload (untested on device)
- [x] 2 Bellman walk-through: player mask +4, bellman mask +8, contact = wake/catch, catch_range 1.15
- [x] 3 iOS Safari freeze (UNTESTED on device): audio deferred to user gesture, web low-quality preset (no shadows, light distance-fade, 30fps mobile), shadow atlas .web=512; already compat renderer, threads off, etc2_astc on
- [x] 4 Touch look ~4x slower, follows look sensitivity; pause-menu slider (touch + mouse)
- [x] 5 Web: low-quality preset always (_apply_web_low_quality), FPS cap 60 desktop web / 30 mobile web
- [x] Export build-9: headless export OK (0 errors), zip at /workspace/work/last-toll/build-9-web.zip
- Leftover: no device test (iPhone 16 Safari); no explicit shader pre-warm pass; not uploaded to itch.io
