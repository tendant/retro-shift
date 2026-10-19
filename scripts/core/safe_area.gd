class_name SafeArea
extends RefCounted
## Window-pixel insets that keep UI clear of notches, rounded corners and the
## home indicator (§10): Vector4(left, top, right, bottom). Zero on desktop
## unless simulated with --safe-area=L,T,R,B.


static func insets(window: Window) -> Vector4:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--safe-area="):
			var parts := arg.trim_prefix("--safe-area=").split_floats(",")
			if parts.size() == 4:
				return Vector4(parts[0], parts[1], parts[2], parts[3])
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var safe := Rect2(DisplayServer.get_display_safe_area())
	var win := Rect2(Vector2(window.position), Vector2(window.size))
	return Vector4(
		maxf(0.0, safe.position.x - win.position.x),
		maxf(0.0, safe.position.y - win.position.y),
		maxf(0.0, win.end.x - safe.end.x),
		maxf(0.0, win.end.y - safe.end.y))
