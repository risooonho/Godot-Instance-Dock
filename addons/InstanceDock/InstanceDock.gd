tool
extends PanelContainer
var edited := true

const PROJECT_SETTING = "addons/instance_dock/scenes"

onready var tabs := $VBoxContainer/HBoxContainer/Tabs
onready var tab_add_confirm := $Control/ConfirmationDialog2
onready var tab_add_name := tab_add_confirm.get_node("LineEdit")
onready var tab_delete_confirm := $Control/ConfirmationDialog

onready var scroll := $VBoxContainer/ScrollContainer
onready var slot_container := $VBoxContainer/ScrollContainer/VBoxContainer/GridContainer
onready var add_tab_label := $VBoxContainer/ScrollContainer/VBoxContainer/Label
onready var drag_label := $VBoxContainer/ScrollContainer/VBoxContainer/Label2

onready var icon_generator := $Viewport

var scenes: Dictionary
var icon_cache: Dictionary
var scrolls: Array
var previous_tab: int

var tab_to_remove: int
var icon_queue: Array
var icon_progress: int

var plugin: EditorPlugin

func _ready() -> void:
	set_process(false)
	if not edited:
		if ProjectSettings.has_setting(PROJECT_SETTING):
			scenes = ProjectSettings.get_setting(PROJECT_SETTING)
		else:
			ProjectSettings.set_setting(PROJECT_SETTING, scenes)
		
		for key in scenes:
			tabs.add_tab(key)
		
		refresh_tabs()
	
	for i in tabs.get_tab_count():
		scrolls.append(0)

func add_tab_pressed() -> void:
	tab_add_name.text = ""
	tab_add_confirm.popup_centered()

func add_tab_confirm() -> void:
	tabs.add_tab(tab_add_name.text)
	scenes[tab_add_name.text] = []
	scrolls.append(0)
	refresh_tabs()

func tab_close_attempt(tab: int) -> void:
	tab_to_remove = tab
	tab_delete_confirm.popup_centered()

func remove_tab_confirm() -> void:
	tabs.remove_tab(tab_to_remove)
	scenes.erase(scenes.keys()[tab_to_remove])
	scrolls.remove(tab_to_remove)
	refresh_tabs()
	scroll.scroll_vertical = scrolls[tabs.current_tab]

func on_tab_changed(tab: int) -> void:
	scrolls[previous_tab] = scroll.scroll_vertical
	refresh_tabs()
	previous_tab = tab
	yield(get_tree(), "idle_frame")
	yield(get_tree(), "idle_frame")
	scroll.scroll_vertical = scrolls[tabs.current_tab]

func refresh_tabs():
	for c in slot_container.get_children():
		c.queue_free()
	
	if tabs.get_tab_count() == 0:
		slot_container.hide()
		add_tab_label.show()
		drag_label.hide()
		return
	else:
		slot_container.show()
		add_tab_label.hide()
		drag_label.show()
	
	var tab_scenes = scenes[scenes.keys()[tabs.current_tab]]
	
	for i in ceil((tab_scenes.size() + 1) / 5.0) * 5:
		var slot = add_slot(i)
		
		if i < tab_scenes.size() and tab_scenes[i]:
			slot.set_scene(tab_scenes[i])
			
			var icon = icon_cache.get(tab_scenes[i], null)
			if icon:
				slot.set_texture(icon)
			else:
				var instance = load(tab_scenes[i]).instance()
				generate_icon(instance as Node2D, slot)

func scene_set(scene: String, slot: int):
	var tab_scenes = scenes[scenes.keys()[tabs.current_tab]]
	if tab_scenes.size() <= slot:
		tab_scenes.resize(slot + 1)
	
	tab_scenes[slot] = scene
	
	if slot == slot_container.get_child_count() - 1:
		for i in 5:
			add_slot(slot + i + 1)

func remove_scene(slot: int):
	var tab_scenes = scenes[scenes.keys()[tabs.current_tab]]
	tab_scenes[slot] = ""
	while not tab_scenes.empty() and tab_scenes.back() == "":
		tab_scenes.pop_back()

func _process(delta: float) -> void:
	if icon_queue.empty():
		set_process(false)
		return
	
	var instance = icon_queue.front()[0]
	var slot = icon_queue.front()[1]
	
	while not is_instance_valid(slot):
		icon_progress = 0
		icon_queue.pop_front()
		instance.free()
		
		if not icon_queue.empty():
			instance = icon_queue.front()[0]
			slot = icon_queue.front()[1]
		else:
			return
	
	match icon_progress:
		0:
			icon_generator.add_child(instance)
			instance.position = Vector2(32, 32)
		3:
			var texture = ImageTexture.new()
			texture.create_from_image(icon_generator.get_texture().get_data())
			slot.set_texture(texture)
			icon_cache[slot.scene] = texture
			instance.free()
			
			icon_progress = -1
			icon_queue.pop_front()
	
	icon_progress += 1

func generate_icon(instance: Node2D, slot: Control):
	icon_queue.append([instance, slot])
	set_process(true)

func add_slot(scene_id: int) -> Control:
	var slot = preload("res://addons/InstanceDock/InstanceSlot.tscn").instance()
	slot.plugin = plugin
	slot_container.add_child(slot)
	slot.connect("request_icon", self, "generate_icon", [slot])
	slot.connect("scene_set", self, "scene_set", [scene_id])
	slot.connect("remove_scene", self, "remove_scene", [scene_id])
	return slot
