class_name SaveStorage
extends RefCounted
## Where saves live (§8). Desktop uses files in user://; console profiles or
## cloud saves plug in by overriding these methods.


## Contents of `file_name`, or "" if it doesn't exist.
func read_text(_file_name: String) -> String:
	return ""


## Replaces `file_name` atomically. Returns false on failure.
func write_text(_file_name: String, _text: String) -> bool:
	return false


func exists(_file_name: String) -> bool:
	return false
