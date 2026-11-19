# build-9 resume notes
Godot 4.3 arm64 binary: /workspace/work/godot (templates in ~/.local/share/godot/export_templates/4.3.stable).
Smoke: `godot --headless -- --smoke` (63 PASS baseline).
- [x] 1 Bell pickup crash: guarded freed nodes, double pickup, timers after scene reload (untested on device)
- [x] 2 Bellman walk-through: player mask +4, bellman mask +8, contact = wake/catch, catch_range 1.15
- [ ] 3 iOS Safari freeze at objective HUD
- [ ] 4 Touch sensitivity
- [ ] 5 Web FPS cap / low preset
- [ ] Export build-9 zip -> /workspace/work/last-toll/build-9-web.zip
