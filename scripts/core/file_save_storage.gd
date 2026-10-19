class_name FileSaveStorage
extends SaveStorage
## Saves as files under a directory (default user://).

var root: String


func _init(p_root: String = "user://") -> void:
	root = p_root


func read_text(file_name: String) -> String:
	var path := root.path_join(file_name)
	if not FileAccess.file_exists(path):
		return ""
	return FileAccess.get_file_as_string(path)


## Writes to a temp file and renames it over the target, so a crash mid-write
## never leaves a truncated save.
func write_text(file_name: String, text: String) -> bool:
	var path := root.path_join(file_name)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s: %s" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	file.close()
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		push_error("Can't replace %s: %s" % [path, error_string(err)])
		return false
	return true


func exists(file_name: String) -> bool:
	return FileAccess.file_exists(root.path_join(file_name))
