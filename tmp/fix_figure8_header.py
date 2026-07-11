from pathlib import Path
import re

p = Path("scenes/tracks_3d/TrackFigure8.tscn")
t = p.read_text(encoding="utf-8")
t = re.sub(
    r'\[ext_resource type="Script"[^\]]*\]',
    '[ext_resource type="Script" path="res://scripts/tracks_3d/TrackFigure8.gd" id="1_script"]',
    t,
    count=1,
)
t = t.replace('[node name="TrackDefault"', '[node name="TrackFigure8"')
t = t.replace('track_display_name = "Starter Circuit"', 'track_display_name = "Figure-8 Chaos"')
p.write_text(t, encoding="utf-8")
print("OK")
print("\n".join(p.read_text(encoding="utf-8").splitlines()[:14]))
