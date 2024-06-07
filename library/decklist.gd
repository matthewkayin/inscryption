extends Node2D

signal edit_deck_pressed

@onready var director = get_node("/root/Director")

@onready var sfx_ok = get_node("../sfx/ok")
@onready var sfx_back = get_node("../sfx/back")

@onready var scroll_up_button = $decklist/scroll_up_button
@onready var scroll_down_button = $decklist/scroll_down_button
@onready var deck_controls = $decklist/cards.get_children()
@onready var deck_new_buttons = $decklist/news.get_children()
@onready var equipped_icon = $decklist/equipped
var deck_name_labels = []
var deck_name_edits = []
var deck_edit_buttons = []
var deck_delete_buttons = []

@export var frame: Texture2D
@export var frame_hover: Texture2D

var scroll_offset = 0
var name_edit_index = -1
var edit_deck_index = -1

enum DeckControlState {
    HIDDEN,
    SHOW,
    EDIT,
    NEW
}

func _ready():
    for index in range(0, deck_controls.size()):
        var deck_control = deck_controls[index]
        deck_name_labels.push_back(deck_control.get_node("name"))
        deck_edit_buttons.push_back(deck_control.get_node("edit"))
        deck_delete_buttons.push_back(deck_control.get_node("delete"))
        deck_name_edits.push_back(deck_control.get_node("name_edit"))

        var label = deck_name_labels[index]
        var label_settings = label.label_settings
        label.label_settings = LabelSettings.new()
        label.label_settings.font = label_settings.font
        label.label_settings.font_size = label_settings.font_size
        label.label_settings.line_spacing = label_settings.line_spacing
        label.label_settings.font_color = label_settings.font_color

        deck_edit_buttons[index].pressed.connect(_on_edit_pressed.bind(index))
        deck_delete_buttons[index].pressed.connect(_on_delete_pressed.bind(index))
        deck_new_buttons[index].pressed.connect(_on_new_pressed)

    scroll_up_button.pressed.connect(_on_scroll_up)
    scroll_down_button.pressed.connect(_on_scroll_down)
    close()

func has_invalid_decks():
    for index in director.decks.size():
        if director.decks[index].cards.size() != Library.MAX_DECK_SIZE:
            return true
    return false

func scroll_offset_max():
    return max(1 + director.decks.size() - deck_controls.size(), 0)

func open():
    refresh()
    visible = true

func close():
    for i in range(0, deck_controls.size()):
        set_deck_control_state(i, DeckControlState.HIDDEN)
    scroll_up_button.is_enabled = false
    scroll_down_button.is_enabled = false
    visible = false

func set_deck_control_state(control_index: int, state: DeckControlState):
    var deck_index = control_index + scroll_offset

    deck_controls[control_index].visible = state == DeckControlState.EDIT or state == DeckControlState.SHOW
    deck_name_labels[control_index].visible = state == DeckControlState.SHOW
    if state == DeckControlState.SHOW:
        var is_deck_valid = director.decks[deck_index].cards.size() == Library.MAX_DECK_SIZE
        deck_name_labels[control_index].label_settings.font_color = Color.BLACK if is_deck_valid else Card.LOW_HEALTH_COLOR

    deck_name_edits[control_index].visible = state == DeckControlState.EDIT
    deck_name_edits[control_index].editable = state == DeckControlState.EDIT

    deck_edit_buttons[control_index].visible = (state == DeckControlState.SHOW or state == DeckControlState.EDIT) and not director.decks[deck_index].is_starter_deck
    deck_edit_buttons[control_index].is_enabled = name_edit_index == -1 and state == DeckControlState.SHOW and deck_edit_buttons[control_index].visible
    deck_delete_buttons[control_index].visible = deck_edit_buttons[control_index].visible
    deck_delete_buttons[control_index].is_enabled = name_edit_index == -1 and state == DeckControlState.SHOW and deck_delete_buttons[control_index].visible

    deck_new_buttons[control_index].visible = state == DeckControlState.NEW
    deck_new_buttons[control_index].is_enabled = name_edit_index == -1 and state == DeckControlState.NEW

func refresh():
    scroll_up_button.visible = scroll_offset > 0 and name_edit_index == -1
    scroll_up_button.is_enabled = scroll_up_button.visible
    scroll_down_button.visible = director.decks.size() - scroll_offset > deck_controls.size() - 1 and name_edit_index == -1
    scroll_up_button.is_enabled = scroll_up_button.visible

    equipped_icon.visible = false

    for control_index in range(0, deck_controls.size()):
        var deck_index = control_index + scroll_offset

        if deck_index == director.decks.size():
            set_deck_control_state(control_index, DeckControlState.NEW)
            continue

        if deck_index > director.decks.size():
            set_deck_control_state(control_index, DeckControlState.HIDDEN)
            continue

        if deck_index == director.player_equipped_deck:
            equipped_icon.visible = true
            equipped_icon.position.y = deck_controls[control_index].position.y + (deck_controls[control_index].size.y / 2)
        
        set_deck_control_state(control_index, DeckControlState.EDIT if name_edit_index == deck_index else DeckControlState.SHOW)
        deck_name_labels[control_index].text = director.decks[deck_index].name
        deck_name_edits[control_index].text = director.decks[deck_index].name

func _on_edit_pressed(index: int):
    sfx_ok.play()
    edit_deck_index = index + scroll_offset
    edit_deck_pressed.emit()
    close()

func _on_delete_pressed(index: int):
    sfx_back.play()
    var deck_index = index + scroll_offset
    director.decks.remove_at(deck_index)
    if director.player_equipped_deck == deck_index:
        director.player_equipped_deck = -1
    scroll_offset = min(scroll_offset, scroll_offset_max())
    refresh()

func _on_new_pressed():
    sfx_ok.play()
    director.decks.push_back({
        "name": "New Deck",
        "cards": [],
        "is_starter_deck": false
    })
    scroll_offset = scroll_offset_max()
    refresh()
    
func _on_scroll_up():
    scroll_offset -= 1
    refresh()

func _on_scroll_down():
    scroll_offset += 1
    refresh()

func name_edit_close():
    director.decks[name_edit_index].name = deck_name_edits[name_edit_index - scroll_offset].text
    name_edit_index = -1
    refresh()

func _process(_delta):
    if not visible:
        return

    if Input.is_action_just_pressed("scroll_up") and scroll_up_button.visible:
        _on_scroll_up()
    if Input.is_action_just_pressed("scroll_down") and scroll_down_button.visible:
        _on_scroll_down()

    var mouse_pos = get_viewport().get_mouse_position()
    var control_hover_index = -1
    for control_index in range(0, deck_controls.size()):
        if not deck_controls[control_index].visible:
            continue
        if deck_controls[control_index].get_global_rect().has_point(mouse_pos):
            control_hover_index = control_index
            if name_edit_index == -1:
                deck_controls[control_index].texture = frame_hover
            else:
                deck_controls[control_index].texture = frame
        else:
            deck_controls[control_index].texture = frame

    if Input.is_action_just_pressed("mouse_button_right"):
        if name_edit_index == -1 and control_hover_index != -1:
            name_edit_index = control_hover_index + scroll_offset
            refresh()
            return
    if Input.is_action_just_pressed("mouse_button_left"):
        if name_edit_index != -1 and control_hover_index != name_edit_index - scroll_offset:
            name_edit_close()
            return
        if control_hover_index == -1:
            return
        var deck_index = control_hover_index + scroll_offset
        var is_deck_valid = director.decks[deck_index].cards.size() == Library.MAX_DECK_SIZE
        if not is_deck_valid:
            return
        sfx_ok.play()
        director.player_equipped_deck = deck_index
        refresh()
    if Input.is_action_just_pressed("enter"):
        if name_edit_index != -1:
            name_edit_close()
            return
