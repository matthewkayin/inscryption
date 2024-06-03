extends Node2D

@onready var director = get_node("/root/Director")

@onready var card_area_row1 = $card_area/card_row1
@onready var card_area_row2 = $card_area/card_row2
@onready var card_hover = $card_hover

@onready var decklist_cards = $decklist/cards.get_children()
@onready var decklist_card_hover = $decklist_card_hover

@onready var decklist_scroll_up_button = $decklist/scroll_up_button
@onready var decklist_scroll_down_button = $decklist/scroll_down_button
@onready var trash_button = $trash_button
@onready var save_button = $save_button
@onready var card_area_page_left = $card_area/page_left
@onready var card_area_page_right = $card_area/page_right

const LIBRARY_EXCLUDE = [
    Card.CardName.SQUIRREL,
    Card.CardName.THE_SMOKE
]
const CARD_AREA_PAGE_SIZE = 8
var CARD_AREA_LAST_PAGE  
var library = []
var card_area_cards = []
var card_area_page_number = 0

const MAX_DECK_SIZE = 20
const CARD_DUPLICATE_LIMIT = 4
var deck = []

var decklist_scroll_offset = 0

func _ready():
    for card_control in card_area_row1.get_children():
        card_area_cards.push_back(card_control.get_child(0))
    for card_control in card_area_row2.get_children():
        card_area_cards.push_back(card_control.get_child(0))
    for card in card_area_cards:
        card.card_init(Card.CardName.SQUIRREL)

    decklist_scroll_up_button.pressed.connect(_on_scroll_up)
    decklist_scroll_down_button.pressed.connect(_on_scroll_down)
    trash_button.pressed.connect(_on_trash_pressed)
    save_button.pressed.connect(_on_save_pressed)
    card_area_page_left.pressed.connect(_on_page_left_pressed)
    card_area_page_right.pressed.connect(_on_page_right_pressed)

func open():
    library = []
    for card_index in range(0, Card.CardName.keys().size()):
        var should_exclude = false
        for excluded_index in LIBRARY_EXCLUDE:
            if card_index == int(excluded_index):
                should_exclude = true
                break
        if should_exclude:
            continue
        library.push_back({
            "card_name": card_index,
            "quantity": CARD_DUPLICATE_LIMIT
        })

    deck = []
    for card in director.player_deck:
        for library_card in library:
            if library_card.card_name == card:
                library_card.quantity -= 1
                break
        var card_entered = false
        for existing_card in deck:
            if existing_card.card_name == card:
                existing_card.quantity += 1
                card_entered = true
        if not card_entered:
            var data = Card.load_data(card)
            deck.push_back({
                "card_name": card,
                "quantity": 1,
                "data": data
            })

    CARD_AREA_LAST_PAGE = int(float(library.size()) / float(CARD_AREA_PAGE_SIZE))
    card_area_refresh()

    decklist_scroll_offset = 0
    decklist_refresh()

    rulebook_close()
    visible = true

func close():
    _on_save_pressed()
    deck = []
    visible = false

func deck_card_count():
    var count = 0
    for card in deck:
        count += card.quantity
    return count

func _on_scroll_up():
    decklist_scroll_offset -= 1
    decklist_refresh()

func _on_scroll_down():
    decklist_scroll_offset += 1
    decklist_refresh()

func _on_trash_pressed():
    deck = []
    decklist_refresh()

func _on_save_pressed():
    director.player_deck = []
    for card in deck:
        for i in range(0, card.quantity):
            director.player_deck.push_back(card.card_name)

func _on_page_left_pressed():
    card_area_page_number = max(card_area_page_number - 1, 0)
    card_area_refresh()

func _on_page_right_pressed():
    card_area_page_number = min(card_area_page_number + 1, CARD_AREA_LAST_PAGE)
    card_area_refresh()

func _process(_delta):
    if not visible:
        return
    var mouse_pos = get_viewport().get_mouse_position()

    if Input.is_action_just_pressed("scroll_up") and decklist_scroll_up_button.visible:
        _on_scroll_up()
    if Input.is_action_just_pressed("scroll_down") and decklist_scroll_down_button.visible:
        _on_scroll_down()

    # Check card hover
    var hovered_card = null
    var hovered_card_index = -1
    for i in range(0, card_area_cards.size()):
        var card = card_area_cards[i]
        if not card.visible:
            continue
        if card.dim.visible:
            continue
        if card.has_point(mouse_pos):
            hovered_card = card
            hovered_card_index = i
            break

    # Hide card hover
    if hovered_card == null and card_hover.visible:
        card_hover.close()
        rulebook_close()
    if hovered_card != null:
        # Show card hover
        if not card_hover.visible or (card_hover.visible and card_hover.position != hovered_card.global_position):
            card_hover.open(hovered_card.global_position)
            rulebook_open(hovered_card)

        # On clicked Card Area card
        if Input.is_action_just_pressed("mouse_button_left"):
            # Check if deck is full
            if deck_card_count() == MAX_DECK_SIZE:
                return
            # Check if card already exists in deck
            var card_entered_deck = false
            for existing_card in deck:
                if existing_card.card_name == hovered_card.card_name:
                    # Don't add the card if we've hit the duplicate limit
                    if existing_card.quantity == CARD_DUPLICATE_LIMIT:
                        return
                    # If it exists, increase the quantity
                    existing_card.quantity += 1
                    card_entered_deck = true
            # If it does not exist, make a new entry in the decklist
            if not card_entered_deck:
                deck.push_back({
                    "card_name": hovered_card.card_name,
                    "quantity": 1,
                    "data": hovered_card.data
                })
            # Remove a copy of the card from the library
            var library_index = (card_area_page_number * CARD_AREA_PAGE_SIZE) + hovered_card_index
            library[library_index].quantity -= 1
            if library[library_index].quantity == 0:
                hovered_card.dim.visible = true
            # Scroll to the bottom of the list
            decklist_scroll_offset = decklist_scroll_offset_max()
            decklist_refresh()
        return

    # Check decklist card hover
    var hovered_decklist_card = null
    var hovered_decklist_card_index = -1
    for i in range(0, decklist_cards.size()):
        var card = decklist_cards[i]
        if not card.visible:
            continue
        if Rect2(card.global_position, card.size).has_point(mouse_pos):
            hovered_decklist_card = card
            hovered_decklist_card_index = i
            break
    
    # Hide decklist card hover
    if hovered_decklist_card == null and decklist_card_hover.visible:
        decklist_card_hover.close()
        rulebook_close()
    if hovered_decklist_card != null:
        # Show card hover
        var decklist_card_hover_position = hovered_decklist_card.global_position - Vector2(4, 4)
        if not decklist_card_hover.visible or (decklist_card_hover.visible and decklist_card_hover.position != decklist_card_hover_position):
            decklist_card_hover.open(decklist_card_hover_position)
            rulebook_open(deck[hovered_decklist_card_index + decklist_scroll_offset])
        if Input.is_action_just_pressed("mouse_button_left"):
            # Find the card in the deck
            var decklist_card_name = hovered_decklist_card.get_node("name").text
            for card in deck:
                var card_name_string = Card.CardName.keys()[card.card_name].capitalize()
                if card_name_string == decklist_card_name:
                    # Remove the card from the deck
                    card.quantity -= 1
                    if card.quantity == 0:
                        deck.erase(card)
                    # Add a copy of the card to the library
                    for library_card in library:
                        if library_card.card_name == card.card_name:
                            library_card.quantity += 1
                    # Scroll up a little if necessary
                    decklist_scroll_offset = min(decklist_scroll_offset, decklist_scroll_offset_max())
                    decklist_refresh()
                    card_area_refresh()
                    break
        return

# CARD AREA

func card_area_refresh():
    card_area_page_left.visible = card_area_page_number != 0
    card_area_page_right.visible = card_area_page_number != CARD_AREA_LAST_PAGE

    var base_card_index = card_area_page_number * CARD_AREA_PAGE_SIZE
    for i in range(0, CARD_AREA_PAGE_SIZE):
        var card = card_area_cards[i]
        var card_index = base_card_index + i
        if card_index < library.size():
            card.card_set_name(library[card_index].card_name)
            card.card_refresh()
            card.dim.visible = library[card_index].quantity == 0
            card.visible = true
        else:
            card.visible = false

# DECKLIST

@onready var decklist_size_label = $size_tab/label

func decklist_scroll_offset_max():
    if deck.size() > decklist_cards.size():
        return deck.size() - decklist_cards.size()
    else:
        return 0

func decklist_refresh():
    decklist_size_label.text = str(deck_card_count()) + "/" + str(MAX_DECK_SIZE)
    decklist_scroll_up_button.visible = decklist_scroll_offset > 0
    decklist_scroll_down_button.visible = (deck.size() - 1) - decklist_scroll_offset > decklist_cards.size() - 1

    decklist_cards[0].visible = not decklist_scroll_up_button.visible
    for decklist_card_index in range(0, decklist_cards.size()):
        var card_index = decklist_card_index + decklist_scroll_offset
        if card_index >= deck.size():
            decklist_cards[decklist_card_index].visible = false
            continue
        decklist_cards[decklist_card_index].visible = true
        decklist_cards[decklist_card_index].get_node("name").text = Card.CardName.keys()[deck[card_index].card_name].capitalize()
        decklist_cards[decklist_card_index].get_node("quantity").text = "x" + str(deck[card_index].quantity)
        decklist_cards[decklist_card_index].get_node("quantity").visible = deck[card_index].quantity > 1

# RULEBOOK

@onready var rulebook_name = $rulebook/name
@onready var rulebook_cost = $rulebook/cost
@onready var rulebook_ability1 = $rulebook/ability1
@onready var rulebook_ability1_name = $rulebook/ability1/name
@onready var rulebook_ability1_desc = $rulebook/ability1/desc
@onready var rulebook_ability1_icon = $rulebook/ability1/icon
@onready var rulebook_ability2 = $rulebook/ability2
@onready var rulebook_ability2_name = $rulebook/ability2/name
@onready var rulebook_ability2_desc = $rulebook/ability2/desc
@onready var rulebook_ability2_icon = $rulebook/ability2/icon
@onready var rulebook_power = $rulebook/power
@onready var rulebook_health = $rulebook/health

func rulebook_open(card):
    # Name
    rulebook_name.text = Card.CardName.keys()[card.card_name].capitalize()

    # Cost
    if card.data.cost_type == CardData.CostType.NONE:
        rulebook_cost.visible = false
    else:
        rulebook_cost.visible = true
        rulebook_cost.frame_coords.y = int(card.data.cost_type) - 1
        rulebook_cost.frame_coords.x = card.data.cost_amount - 1

    # Ability 1
    if card.data.ability1 == Ability.Name.NONE:
        rulebook_ability1.visible = false
    else:
        rulebook_ability1.visible = true
        rulebook_ability1_name.text = Ability.name_str(card.data.ability1)
        rulebook_ability1_desc.text = Ability.DESC[card.data.ability1]
        rulebook_ability1_icon.texture = Ability.load_icon(card.data.ability1)

    # Ability 2
    if card.data.ability2 == Ability.Name.NONE:
        rulebook_ability2.visible = false
    else:
        rulebook_ability2.visible = true
        rulebook_ability2_name.text = Ability.name_str(card.data.ability2)
        rulebook_ability2_desc.text = Ability.DESC[card.data.ability2]
        rulebook_ability2_icon.texture = Ability.load_icon(card.data.ability2)

    # Power and Health
    rulebook_power.text = str(card.data.power)
    rulebook_health.text = str(card.data.health)

func rulebook_close():
    rulebook_name.text = ""
    rulebook_cost.visible = false
    rulebook_ability1.visible = false
    rulebook_ability2.visible = false
    rulebook_power.text = ""
    rulebook_health.text = ""
