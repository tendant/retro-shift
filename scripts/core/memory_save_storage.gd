class_name MemorySaveStorage
extends SaveStorage
## In-memory storage for tests and throwaway sessions.

var files: Dictionary = {}


func read_text(file_name: String) -> String:
	return files.get(file_name, "")


func write_text(file_name: String, text: String) -> bool:
	files[file_name] = text
	return true


func exists(file_name: String) -> bool:
	return files.has(file_name)
