extends Node2D

signal server_ready
signal player_deck_draw_finished

@onready var director = get_node("/root/Director")
@onready var network = get_node("/root/Network")

@onready var card_scene = preload("res://match/card/card.tscn")

@onready var score_scale = $scale
@onready var card_hover = $card_hover
@onready var rulebook = $rulebook
@onready var rulebook_name_label = $rulebook/name
@onready var rulebook_desc_label = $rulebook/desc
@onready var rulebook_icon = $rulebook/icon
@onready var player_cardslots = $player_cardslots.get_children()
@onready var opponent_cardslots = $opponent_cardslots.get_children()
@onready var bell = $bell
@onready var attack_animation = $attack_animation
@onready var bone_counter_label = $bone_counter/value
@onready var player_candles = $player_candles
@onready var opponent_candles = $opponent_candles
@onready var deck = $deck
@onready var deck_count_label = $deck/value
@onready var squirrel_deck = $squirrel_deck
@onready var squirrel_deck_count_label = $squirrel_deck/value
@onready var popup = $popup
@onready var fade = $fade
var blood_counter_sprites = []
@onready var sfx_sacrifice = $sfx/sacrifice
@onready var sfx_death = $sfx/death
@onready var sfx_win = $sfx/win
@onready var sfx_scale = $sfx/scale
@onready var sfx_attack = $sfx/attack
@onready var sfx_crunch = $sfx/crunch
@onready var sfx_blip = $sfx/blip
@onready var bone_popup = $bone_popup
@onready var bone_popup_value = $bone_popup/value
@onready var concede_menu = $concede_menu

enum State {
    WAIT,
    PLAYER_DRAW,
    PLAYER_TURN,
    PLAYER_SUMMONING,
    PLAYER_DECK_DRAW
}

enum BellState {
    READY,
    DISABLED,
    HOVER,
    PRESS
}

enum Turn {
    PLAYER,
    OPPONENT
}

const CAT_LIVES = 9

const BELL_SIZE = Vector2(182, 72)
@onready var BELL_RECT = Rect2(bell.position - (BELL_SIZE * 0.5), BELL_SIZE)

var state = State.WAIT
var player_hand = []
var player_deck_hand = []
var player_deck_hand_visible = false
var player_board = [null, null, null, null]
var player_score = 0
var player_bone_count = 0
var player_deck = []
var player_squirrel_deck_count = 20
var opponent_hand = []
var opponent_board = [null, null, null, null]
var opponent_score = 0
var opponent_bone_count = 0

var summoning_card = null
var summoning_cost_met = false
var summoning_blood_count = 0
var summoning_blood_count_this_turn = 0

var network_action_queue = []
var network_is_action_running = false

var is_game_over = false
var is_process_disabled = false
var is_server_ready = false

var skip_draw = false
var skip_combat = false

func _ready():
    # Setup
    for child in $blood_counter.get_children():
        blood_counter_sprites.push_back(child.get_child(0))
    bell.frame_coords.x = int(BellState.DISABLED)
    score_scale.display_scores(0, 0)
    network.server_client_disconnected.connect(_on_opponent_disconnect)
    network.client_server_disconnected.connect(_on_opponent_disconnect)
    bone_popup.visible = false
    concede_menu.player_conceded.connect(_on_player_concede)
    rulebook_close()

    # Init player deck
    var deck_unshuffled = []
    for card in director.decks[director.player_equipped_deck].cards:
        deck_unshuffled.push_back(card) 
    while not deck_unshuffled.is_empty():
        player_deck.push_back(deck_unshuffled.pop_at(randi_range(0, deck_unshuffled.size() - 1)))

    # Init opponent hand
    for i in range(0, 4):
        opponent_hand_add_card()
    # Init player hand
    await hand_add_card(Card.SQUIRREL)
    var cards_in_hand = 1
    while cards_in_hand != 4:
        if not player_deck.is_empty():
            await hand_add_card(player_deck.pop_front())
        else:
            await hand_add_card(Card.SQUIRREL)
            player_squirrel_deck_count -= 1
        cards_in_hand += 1

    ui_update_deck_counters()

    if not network.network_is_connected():
        state = State.PLAYER_DRAW
    else:
        state = State.WAIT
        if not multiplayer.is_server():
            _on_client_ready.rpc_id(network.opponent_id)
        else:
            is_server_ready = true
            server_ready.emit()

@rpc("any_peer", "reliable")
func _on_client_ready():
    if not is_server_ready:
        await server_ready
    var server_goes_first = bool(randi_range(0, 1))
    _on_server_declared_first_turn.rpc_id(network.opponent_id, server_goes_first)
    state = State.PLAYER_DRAW if server_goes_first else State.WAIT
    var message = "You go first." if server_goes_first else "Opponent goes first."
    skip_draw = server_goes_first
    popup.open(message, 1.0)

@rpc("any_peer", "reliable")
func _on_server_declared_first_turn(server_goes_first):
    state = State.WAIT if server_goes_first else State.PLAYER_DRAW
    var message = "Opponent goes first" if server_goes_first else "You go first." 
    skip_draw = not server_goes_first
    popup.open(message, 1.0)

func _process(_delta):
    if is_process_disabled:
        print(network.player.name, ": process disabled")
        return
    if is_game_over:
        if Input.is_action_just_pressed("mouse_button_left"):
            is_process_disabled = true
            var tween = get_tree().create_tween()
            tween.tween_property(fade, "color", Color(0, 0, 0, 1), 1.0)
            await tween.finished
            director.end_match()
        return
    if Input.is_action_just_pressed("escape"):
        if concede_menu.visible:
            concede_menu.close()
        else:
            concede_menu.open()
            return
    if concede_menu.visible:
        return
    if state == State.WAIT or state == State.PLAYER_DRAW:
        player_hand_process()
    if state == State.WAIT:
        network_process()
    if rulebook.visible:
        rulebook_process()
        return
    if state == State.WAIT:
        return
    call(State.keys()[state].to_lower() + "_process")

# HAND

func hand_update_positions():
    await hand_update_positions_helper(player_hand, 407)

func deck_hand_update_positions():
    await hand_update_positions_helper(player_deck_hand, 200)

func hand_update_positions_helper(hand, hand_center_y):
    var HAND_CENTER = Vector2(320, hand_center_y)
    const HAND_UPDATE_DURATION = 0.25

    var hand_size = hand.size()
    var HAND_CARD_PADDING 
    if hand_size < 6:
        HAND_CARD_PADDING = 98
    elif hand_size == 6:
        HAND_CARD_PADDING = 90
    else:
        const LAST_CARD_POSITION = 532.0 - 82.0
        HAND_CARD_PADDING = LAST_CARD_POSITION / (hand_size - 1)

    if hand.size() == 0:
        return
    var tween = get_tree().create_tween()
    if hand.size() == 1:
        tween.parallel().tween_property(hand[0], "position", HAND_CENTER, HAND_UPDATE_DURATION)
    else: 
        var hand_area_size 
        var hand_area_start 
        if hand_size < 7:
            hand_area_size = (hand.size() * HAND_CARD_PADDING) - (HAND_CARD_PADDING - Card.CARD_SIZE.x)
            hand_area_start = 320 - int(hand_area_size / 2.0) + (Card.CARD_SIZE.x / 2.0)
        else:
            hand_area_size = 532.0
            hand_area_start = 95.0
        for i in range(0, hand.size()):
            var card_x = hand_area_start + (i * HAND_CARD_PADDING)
            tween.parallel().tween_property(hand[i], "position", Vector2(card_x, HAND_CENTER.y), HAND_UPDATE_DURATION)
    await tween.finished

func hand_add_card(card_id: int):
    var card_instance = card_scene.instantiate()
    card_instance.card_init(card_id)
    hand_add_card_instance(card_instance)

func hand_add_card_instance(card_instance: Card):
    const CARD_SPAWN_POS = Vector2(681, 407)

    add_child(card_instance)
    card_instance.position = CARD_SPAWN_POS
    player_hand.append(card_instance)

    await hand_update_positions()

func opponent_hand_add_card():
    const CARD_SPAWN_POS = Vector2(681, -24)

    var opponent_card = card_scene.instantiate()
    opponent_card.card_init(Card.SQUIRREL, true)
    add_child(opponent_card)
    opponent_card.position = CARD_SPAWN_POS
    opponent_hand.append(opponent_card)

    await opponent_hand_update_positions()

func opponent_hand_update_positions():
    const HAND_CENTER = Vector2(426, -24)
    const HAND_UPDATE_DURATION = 0.25

    if opponent_hand.size() == 0:
        return
    if opponent_hand.size() == 1:
        var tween1 = get_tree().create_tween()
        tween1.parallel().tween_property(opponent_hand[0], "position", HAND_CENTER, HAND_UPDATE_DURATION)
        await tween1.finished
        return
    
    var hand_area_size = min(276.0, opponent_hand.size() * (0.5 * Card.CARD_SIZE.x))
    var HAND_CARD_PADDING = hand_area_size / (opponent_hand.size() - 1)
    var hand_area_start = HAND_CENTER.x - (hand_area_size * 0.5)

    var tween = get_tree().create_tween()
    for i in range(0, opponent_hand.size()):
        var card_x = hand_area_start + (i * HAND_CARD_PADDING)
        tween.parallel().tween_property(opponent_hand[i], "position", Vector2(card_x, HAND_CENTER.y), HAND_UPDATE_DURATION)
    await tween.finished

# UI

func ui_update_blood_counter():
    for i in range(0, 4):
        if summoning_blood_count > i:
            blood_counter_sprites[i].frame_coords.x = 1
        else:
            blood_counter_sprites[i].frame_coords.x = 0

func ui_update_bone_counter():
    bone_counter_label.text = "x" + str(player_bone_count)

func ui_update_deck_counters():
    deck_count_label.text = "x" + str(player_deck.size())
    squirrel_deck_count_label.text = "x" + str(player_squirrel_deck_count)

func ui_animate_bone_popup(who: Turn, index: int, bone_count: int):
    var cardslots = player_cardslots if who == Turn.PLAYER else opponent_cardslots
    bone_popup.position = cardslots[index].global_position
    bone_popup.modulate = Color(1, 1, 1, 1)
    bone_popup.visible = true
    bone_popup_value.visible = bone_count > 1
    bone_popup_value.text = "x" + str(bone_count)
    var tween = get_tree().create_tween()
    tween.tween_property(bone_popup, "position", bone_popup.position + Vector2(0, -70), 0.25)
    tween.tween_property(bone_popup, "modulate", Color(1, 1, 1, 0), 0.25)
    await tween.finished
    bone_popup.visible = false

# BOARD

func board_add_card(which: Turn, index: int, card_id: int):
    var card_instance = card_scene.instantiate()
    card_instance.card_init(card_id)
    add_child(card_instance)
    if which == Turn.PLAYER:
        card_instance.position = player_cardslots[index].global_position
        player_board[index] = card_instance
    else:
        card_instance.position = opponent_cardslots[index].global_position
        opponent_board[index] = card_instance

func opponent_board_play_card(index: int, card_id: int, eternal_counter: int = 0, morsel_power: int = 0, morsel_health: int = 0, brood_parasite_roll: float = 0.0):
    var card = opponent_hand[opponent_hand.size() - 1]
    card.z_index = 1

    var tween = get_tree().create_tween()
    tween.tween_property(card, "position", opponent_cardslots[index].global_position, 0.25)
    card.set_card_id(card_id)
    await tween.finished
    if card.has_sprint_ability():
        card.set_sprint_direction(-1)
    card.base_power += eternal_counter
    card.base_health += eternal_counter
    card.power = card.base_power
    card.health = card.base_health
    card.give_morsel(morsel_power, morsel_health)
    await card.card_flip(Card.FlipTo.FRONT)
    if card.data.cost_type == CardData.CostType.BONE:
        opponent_bone_count -= card.data.cost_amount
    sfx_crunch.play()
    card.z_index = 0

    opponent_hand.erase(card)
    opponent_board[index] = card
    await opponent_hand_update_positions()

    await on_card_played(Turn.OPPONENT, card, index, brood_parasite_roll)

func player_summon_card(card: Card, index: int, pay_cost: bool = true):
    var brood_parasite_roll = randf()
    if network.network_is_connected():
        var eternal_counter = 0
        if card.has_ability(Ability.Name.ETERNAL):
            eternal_counter = card.base_power - card.data.power
        _on_opponent_place_card.rpc_id(network.opponent_id, index, card.card_id, eternal_counter, card.morsel_power, card.morsel_health, brood_parasite_roll)

    # Move the card into place
    is_process_disabled = true
    card.z_index = 1
    var tween = get_tree().create_tween()
    tween.tween_property(card, "position", player_cardslots[index].global_position, 0.25)
    await tween.finished
    sfx_crunch.play()
    card.z_index = 0

    # Swap the card out of player hand and onto the board
    player_hand.erase(card)
    player_board[index] = card

    if pay_cost:
        # Update bones
        if card.data.cost_type == CardData.CostType.BONE:
            player_bone_count -= card.data.cost_amount
            ui_update_bone_counter()

        # Update blood
        summoning_blood_count = 0
        ui_update_blood_counter()

    # Update hand
    await hand_update_positions()
    await on_card_played(Turn.PLAYER, player_board[index], index, brood_parasite_roll)
    is_process_disabled = false

func board_animate_guardian(which: Turn, from: int, to: int):
    var board = player_board if which == Turn.PLAYER else opponent_board
    var to_cardslot = player_cardslots[to] if which == Turn.PLAYER else opponent_cardslots[to]
    var card = board[from]
    var direction = 1 if which == Turn.PLAYER else -1

    card.z_index = 1
    var tween = get_tree().create_tween()
    tween.tween_property(card, "position", card.position + (direction * Vector2(0, 16)), 0.125)
    tween.tween_property(card, "position", to_cardslot.global_position + (direction * Vector2(0, 16)), 0.25)
    tween.tween_property(card, "position", to_cardslot.global_position, 0.125)
    await tween.finished
    card.z_index = 0
    sfx_crunch.play()

    board[to] = card
    board[from] = null

func board_kill_card(turn: Turn, index: int, is_sacrifice = false):
    var board = player_board if turn == Turn.PLAYER else opponent_board

    var card = board[index] 
    if is_sacrifice:
        sfx_sacrifice.play()
    else:
        sfx_death.play()
    await card.animate_death(is_sacrifice)
    board[index] = null

    await on_card_died(turn, card, index, is_sacrifice)
    card.queue_free()

func board_compute_powers(which: Turn):
    var board = player_board if which == Turn.PLAYER else opponent_board
    var opposite_board = opponent_board if which == Turn.PLAYER else player_board

    # Determine the number of ants
    var ant_count = 0
    for index in range(0, board.size()):
        if board[index] == null:
            continue
        if board[index].has_ability(Ability.Name.COLONY):
            ant_count += 1

    # Determine the power for each creature
    for index in range(0, board.size()):
        if board[index] == null:
            continue
        # Start with their base power
        board[index].power = board[index].base_power + board[index].morsel_power
        # Apply ant count bonus if it's an ant
        if board[index].has_ability(Ability.Name.COLONY):
            board[index].power += ant_count
        # Give +1 if there is a LEADER on either side
        if index - 1 >= 0 and board[index - 1] != null and board[index - 1].has_ability(Ability.Name.LEADER):
            board[index].power += 1
        if index + 1 < board.size() and board[index + 1] != null and board[index + 1].has_ability(Ability.Name.LEADER):
            board[index].power += 1
        # Give -1 if there is STINKY on other side
        if opposite_board[index] != null and opposite_board[index].has_ability(Ability.Name.STINKY):
            board[index].power -= 1
        # Apply kill bonus if it has BLOOD LUST
        if board[index].has_ability(Ability.Name.BLOOD_LUST):
            board[index].power += board[index].kill_count
        # Apply sacrifice bonus if it has SPILLED BLOOD
        if board[index].has_ability(Ability.Name.SPILLED_BLOOD):
            board[index].power += summoning_blood_count_this_turn
        # Apply bone bonus if it has BONE VIGOR
        if board[index].has_ability(Ability.Name.BONE_VIGOR):
            if which == Turn.PLAYER:
                board[index].power += int(ceil(player_bone_count / 2.0))
            else:
                board[index].power += int(ceil(opponent_bone_count / 2.0))
        board[index].power = max(board[index].power, 0)
        board[index].card_refresh()

# GAME EVENTS

func on_card_played(who: Turn, card: Card, index: int, brood_parasite_roll: float):
    var opposite_player = Turn.OPPONENT if who == Turn.PLAYER else Turn.PLAYER
    var opposite_board = opponent_board if who == Turn.PLAYER else player_board

    if opposite_board[index] == null:
        for opposite_board_index in range(0, opposite_board.size()):
            if opposite_board[opposite_board_index] == null:
                continue
            if opposite_board[opposite_board_index].has_ability(Ability.Name.GUARDIAN):
                await board_animate_guardian(opposite_player, opposite_board_index, index)
                break

    board_compute_powers(Turn.PLAYER)
    board_compute_powers(Turn.OPPONENT)

    if card.has_ability(Ability.Name.ANT_SPAWNER) or card.has_ability(Ability.Name.RABBIT_HOLE):
        if who == Turn.PLAYER:
            await hand_add_card(Card.get_id_from_data(card.data.tail))
        else:
            await opponent_hand_add_card()
    if card.has_ability(Ability.Name.FECUNDITY):
        if who == Turn.PLAYER:
            await hand_add_card(Card.get_id_from_data(card.data))
        else:
            await opponent_hand_add_card()
    if card.has_ability(Ability.Name.HOARDER):
        if player_deck.size() > 0:
            if who == Turn.PLAYER:
                # Tell the opponent we played a magpie
                if network.network_is_connected():
                    _on_opponent_use_hoarder.rpc_id(network.opponent_id)

                state = State.WAIT
                player_deck_hand = []
                for card_id in player_deck:
                    var deck_card = card_scene.instantiate()
                    deck_card.card_init(card_id)
                    add_child(deck_card)
                    deck_card.position = Vector2(640 + Card.CARD_SIZE.x, 240)
                    player_deck_hand.push_back(deck_card)
                    await deck_hand_update_positions()
                player_deck_hand_visible = true
                state = State.PLAYER_DECK_DRAW
                is_process_disabled = false
                await player_deck_draw_finished
            else:
                popup.open("Opponent is choosing a card from their deck.")
    if card.has_ability(Ability.Name.HANDY):
        var hand = player_hand if who == Turn.PLAYER else opponent_hand
        for hand_index in range(0, hand.size()):
            if hand_index == hand.size() - 1:
                await hand[hand_index].animate_death()
            else:
                hand[hand_index].animate_death()
        for hand_card in hand:
            hand_card.queue_free()
        var tween = get_tree().create_tween()
        tween.tween_interval(0.5)
        await tween.finished
        if who == Turn.PLAYER:
            player_hand = []
            for i in range(0, 4):
                if player_deck.is_empty() and player_squirrel_deck_count == 0:
                    break
                _on_opponent_draw_card.rpc_id(network.opponent_id)
                if not player_deck.is_empty():
                    await hand_add_card(player_deck.pop_front())
                else:
                    player_squirrel_deck_count -= 1
                    await hand_add_card(Card.SQUIRREL)
                ui_update_deck_counters()
        else:
            opponent_hand = []
            popup.open("Opponent discards and redraws their hand.", 2.0)
    if card.has_ability(Ability.Name.BROOD_PARASITE):
        if opposite_board[index] == null:
            var spawn_raven_egg = brood_parasite_roll <= 0.1
            board_add_card(opposite_player, index, Card.get_id_from_data(card.data.evolves_into if spawn_raven_egg else card.data.tail))

func on_card_is_about_to_attack(who: Turn, _attacker: Card, index: int):
    var opposite = Turn.OPPONENT if who == Turn.PLAYER else Turn.PLAYER
    var defender_board = player_board if opposite == Turn.PLAYER else opponent_board

    if defender_board[index] == null:
        var defender_indices = [0, 1, 2, 3] if opposite == Turn.PLAYER else [3, 2, 1, 0]
        for defender_index in defender_indices:
            if defender_index == index:
                continue
            if defender_board[defender_index] == null:
                continue
            if defender_board[defender_index].has_ability(Ability.Name.BURROWER):
                await board_animate_guardian(opposite, defender_index, index)
                break

func on_card_hit(who: Turn, card: Card, index: int, attacker: Card):
    var board = player_board if who == Turn.PLAYER else opponent_board
    var cardslots = player_cardslots if who == Turn.PLAYER else opponent_cardslots

    if card.has_ability(Ability.Name.BEES_WITHIN):
        if who == Turn.PLAYER:
            await hand_add_card(Card.get_id_from_data(card.data.tail))
        else:
            await opponent_hand_add_card()
    if card.has_ability(Ability.Name.SHARP):
        attacker.health -= 1
        board_compute_powers(Turn.PLAYER)
        board_compute_powers(Turn.OPPONENT)
    if card.has_ability(Ability.Name.LOOSE_TAIL):
        var free_index = -1
        var direction = 1 if who == Turn.PLAYER else -1
        if index + direction >= 0 and index + direction < board.size() and board[index + direction] == null:
            free_index = index + direction
        elif index - direction >= 0 and index - direction < board.size() and board[index - direction] == null:
            free_index = index - direction
        if free_index != -1:
            var tween = get_tree().create_tween()
            tween.tween_property(card, "position", cardslots[free_index].global_position, 0.25)
            await tween.finished
            board[free_index] = card
            board[index] = null
            var card_tail_id = Card.get_id_from_data(card.data.tail)
            await card.evolve()
            board_add_card(who, index, card_tail_id)
    if card.has_ability(Ability.Name.ARMORED):
        await card.evolve()

func on_card_died(who: Turn, card: Card, index: int, was_sacrifice = false, is_double_death = false):
    var board = player_board if who == Turn.PLAYER else opponent_board
    var opposing_board = opponent_board if who == Turn.PLAYER else player_board
    var opposing_player = Turn.OPPONENT if who == Turn.PLAYER else Turn.PLAYER

    # Compute bone yield
    var bone_yield = 1
    if card.has_ability(Ability.Name.BONE_KING):
        bone_yield = 4

    # Check for a bone thief
    var opposing_has_bone_thief = false
    for opposing_card_index in range(0, 4):
        var opposing_card = opposing_board[opposing_card_index]
        if opposing_card == null:
            continue
        if opposing_card.has_ability(Ability.Name.BONE_THIEF):
            opposing_has_bone_thief = true
            await ui_animate_bone_popup(opposing_player, opposing_card_index, bone_yield)

    # Grant the bones (to card owner or to bone thief owner)
    var who_gets_bones = who if not opposing_has_bone_thief else opposing_player
    if who_gets_bones == Turn.PLAYER:
        player_bone_count += bone_yield
        ui_update_bone_counter()
    else:
        opponent_bone_count += bone_yield

    # MANY LIVES
    if was_sacrifice and card.has_ability(Ability.Name.MANY_LIVES):
        board_add_card(who, index, card.card_id)
        if board[index].sacrifice_count < CAT_LIVES:
            board[index].sacrifice_count = card.sacrifice_count + 1
            if board[index].sacrifice_count == CAT_LIVES:
                if board[index].data.evolves_into != null:
                    await board[index].evolve()

    # UNKILLABLE / ETERNAL
    if card.has_ability(Ability.Name.UNKILLABLE) or card.has_ability(Ability.Name.ETERNAL):
        if who == Turn.PLAYER:
            if card.has_ability(Ability.Name.UNKILLABLE):
                await hand_add_card(card.card_id)
            else:
                var card_copy = card_scene.instantiate()
                card_copy.card_init(card.card_id)
                card_copy.base_power = card.base_power + 1
                card_copy.base_health = card.base_health + 1
                card_copy.power = card_copy.base_power
                card_copy.health = card_copy.base_health
                card_copy.card_refresh()
                await hand_add_card_instance(card_copy)
        else:
            await opponent_hand_add_card()

    # CORPSE EATER
    if board[index] == null and who == Turn.PLAYER and not was_sacrifice:
        for hand_card in player_hand:
            if hand_card.has_ability(Ability.Name.CORPSE_EATER):
                await player_summon_card(hand_card, index, false)
                break

    # DOUBLE DEATH
    if board[index] == null and not is_double_death:
        var should_double_death = false
        for board_index in range(0, board.size()):
            if board_index == index or board[board_index] == null:
                continue
            if board[board_index].has_ability(Ability.Name.DOUBLE_DEATH):
                should_double_death = true
                break
        if should_double_death:
            board_add_card(who, index, card.card_id)
            await board[index].animate_death(false)
            var undead_copy = board[index]
            board[index] = null
            await on_card_died(who, undead_copy, index, false, true)

    board_compute_powers(Turn.PLAYER)
    board_compute_powers(Turn.OPPONENT)

func on_combat_over(who: Turn):
    var attacker_board = player_board if who == Turn.PLAYER else opponent_board
    var attacker_cardslots = player_cardslots if who == Turn.PLAYER else opponent_cardslots
    var defender_board = opponent_board if who == Turn.PLAYER else player_board

    var skip_index = false
    var lane_indices = range(0, 4) if who == Turn.PLAYER else range(3, -1, -1)
    for board_index in lane_indices:
        if skip_index:
            skip_index = false
            continue
        var card = attacker_board[board_index]
        if card == null:
            continue
        # SPRINT
        if card.has_sprint_ability():
            var is_hefty = card.has_ability(Ability.Name.HEFTY)
            var is_rampager = card.has_ability(Ability.Name.RAMPAGER)

            # Determine if blocked
            var direction = card.get_sprint_direction()
            var next_index = board_index + direction
            if is_hefty:
                next_index = board_index
                while next_index >= 0 and next_index < attacker_board.size() and attacker_board[next_index] != null:
                    next_index += direction
            var is_blocked = next_index < 0 or next_index >= attacker_board.size()
            if not is_blocked and attacker_board[next_index] != null and not (is_hefty or is_rampager):
                is_blocked = true
            
            # If so, flip direction
            if is_blocked:
                var tween = get_tree().create_tween()
                tween.tween_property(card, "rotation_degrees", 7, 0.0375)
                tween.tween_property(card, "rotation_degrees", -7, 0.075)
                tween.tween_property(card, "rotation_degrees", 7, 0.075)
                tween.tween_property(card, "rotation_degrees", -7, 0.075)
                tween.tween_property(card, "rotation_degrees", 0, 0.0375)
                await tween.finished
                card.set_sprint_direction(direction * -1)
            # Otherwise, move one space
            else:
                var tween = get_tree().create_tween()
                # HEFTY MOVE
                if is_hefty:
                    # Start from the free space and move everyone over one at a time
                    var dest_index = next_index
                    while dest_index != board_index:
                        var source_index = dest_index - direction
                        tween.parallel().tween_property(attacker_board[source_index], "position", attacker_cardslots[dest_index].global_position, 0.25)
                        attacker_board[dest_index] = attacker_board[source_index]

                        dest_index = source_index
                    attacker_board[board_index] = null
                # RAMPAGER MOVE
                elif is_rampager:
                    if attacker_board[next_index] != null:
                        tween.parallel().tween_property(attacker_board[next_index], "position", card.position, 0.25)
                    attacker_board[board_index] = attacker_board[next_index]
                    tween.parallel().tween_property(card, "position", attacker_cardslots[next_index].global_position, 0.25)
                    attacker_board[next_index] = card
                # SPRINTER MOVE
                else:
                    tween.tween_property(card, "position", attacker_cardslots[next_index].global_position, 0.25)
                    attacker_board[next_index] = card
                    attacker_board[board_index] = null

                    # SPRINTER TAIL DROP
                    if card.data.tail != null:
                        board_add_card(who, board_index, Card.get_id_from_data(card.data.tail))
                        attacker_board[board_index].set_sprint_direction(card.get_sprint_direction())
                await tween.finished

                # If we moved into the next index to be iterated over, skip that index
                if (direction == 1 and who == Turn.PLAYER) or (direction == -1 and who == Turn.OPPONENT):
                    skip_index = true
        if card.has_ability(Ability.Name.SUBMERGE):
            await card.card_flip(Card.FlipTo.SUBMERGE)
        if card.has_ability(Ability.Name.BRITTLE):
            await board_kill_card(who, board_index)
    var defender_lane_indices = range(0, 4) if who == Turn.OPPONENT else range(3, -1, -1)
    for defender_lane_index in defender_lane_indices:
        var card = defender_board[defender_lane_index]
        if card == null:
            continue
        if card.has_ability(Ability.Name.SUBMERGE):
            await card.card_flip(Card.FlipTo.FRONT)
        if card.has_ability(Ability.Name.BONE_DIGGER):
            var tween = get_tree().create_tween()
            tween.tween_property(card, "position", card.position + Vector2(0, 8), 0.25)
            tween.tween_property(card, "position", card.position, 0.125)
            await tween.finished
            await ui_animate_bone_popup(Turn.OPPONENT if who == Turn.PLAYER else Turn.PLAYER, defender_lane_index, 1)
            if who == Turn.OPPONENT:
                player_bone_count += 1
        if card.has_ability(Ability.Name.EVOLVE):
            await card.evolve()

    summoning_blood_count_this_turn = 0
    board_compute_powers(Turn.PLAYER)
    board_compute_powers(Turn.OPPONENT)

# PLAYER DRAW

func player_draw_process():
    const DECK_AREA_SIZE = Vector2(52, 34)
    const DECK_OFFSET = Vector2(-13, -17)

    if skip_draw:
        skip_draw = false
        state = State.PLAYER_TURN
        return

    if not popup.visible:
        popup.open("Draw a card.")

    if player_deck.size() == 0 and player_squirrel_deck_count == 0:
        state = State.WAIT
        if network.network_is_connected():
            _on_opponent_cannot_draw_card.rpc_id(network.opponent_id)
        await popup.open("No cards to draw. Take 1 damage.", 2.0)

        opponent_score += 1

        # Update scale
        score_scale.display_scores(opponent_score, player_score)

        # Delay for suspense
        var tween = get_tree().create_tween()
        tween.tween_interval(0.1)
        await tween.finished

        await check_if_candle_snuffed(Turn.OPPONENT)
        if is_game_over:
            return
        state = State.PLAYER_TURN
        return

    var cursor_type = director.current_cursor
    var mouse_pos = get_viewport().get_mouse_position()

    var drawn_card = null
    var DECK_RECT = Rect2(deck.position + DECK_OFFSET, DECK_AREA_SIZE)
    if player_deck.size() != 0 and DECK_RECT.has_point(mouse_pos):
        cursor_type = director.CursorType.HAND
        if Input.is_action_just_pressed("mouse_button_left"):
            drawn_card = player_deck.pop_back()
    var SQUIRREL_DECK_RECT = Rect2(squirrel_deck.position + DECK_OFFSET, DECK_AREA_SIZE)
    if player_squirrel_deck_count != 0 and SQUIRREL_DECK_RECT.has_point(mouse_pos):
        cursor_type = director.CursorType.HAND
        if Input.is_action_just_pressed("mouse_button_left"):
            drawn_card = Card.SQUIRREL
            player_squirrel_deck_count -= 1

    if drawn_card != null:
        popup.close()
        if network.network_is_connected():
            _on_opponent_draw_card.rpc_id(network.opponent_id)
        state = State.WAIT
        ui_update_deck_counters()
        await hand_add_card(drawn_card)
        state = State.PLAYER_TURN

    director.set_cursor(cursor_type)

# PLAYER TURN

func player_hand_process():
    var cursor_type = director.CursorType.POINTER

    var mouse_pos = get_viewport().get_mouse_position()
    var hovered_card = null
    var selected_card = null

    if player_deck_hand_visible:
        for card in player_deck_hand:
            card.z_index = 0
        for i in range(player_deck_hand.size() - 1, -1, -1):
            var card = player_deck_hand[i]
            if card.has_point(mouse_pos):
                # make sure that card hover is not already open on this card
                hovered_card = card
                if state == State.PLAYER_DECK_DRAW:
                    selected_card = card
                    if not (card_hover.visible and card_hover.position == card.position): 
                        card_hover.open(card.position)
                    break

    if hovered_card == null:
        for card in player_hand:
            card.z_index = 0
        for i in range(player_hand.size() - 1, -1, -1):
            var card = player_hand[i]
            if card.has_point(mouse_pos):
                # make sure that card hover is not already open on this card
                hovered_card = card
                if state == State.PLAYER_TURN:
                    selected_card = card
                    if not (card_hover.visible and card_hover.position == card.position): 
                        card_hover.open(card.position)
                    break

    if hovered_card != null:
        hovered_card.z_index = 1
    if selected_card == null and card_hover.visible:
        card_hover.close()

    # Check if we're hovering over a sigil
    var hovered_ability = Ability.Name.NONE
    if hovered_card != null:
        hovered_ability = hovered_card.get_hovered_ability(mouse_pos)
    else:
        # Check sigil hover on player board
        for i in range(0, player_cardslots.size()):
            var cardslot = player_cardslots[i]
            if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos) and player_board[i] != null:
                hovered_ability = player_board[i].get_hovered_ability(mouse_pos)
                break
        if hovered_ability == Ability.Name.NONE:
            # Check sigil hover on opponent board
            for i in range(0, opponent_cardslots.size()):
                var cardslot = opponent_cardslots[i]
                if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos) and opponent_board[i] != null:
                    hovered_ability = opponent_board[i].get_hovered_ability(mouse_pos)
                    break

    if hovered_ability != Ability.Name.NONE:
        cursor_type = director.CursorType.RULEBOOK

    if hovered_ability != Ability.Name.NONE and Input.is_action_just_pressed("mouse_button_right"):
        card_hover.close()
        rulebook_open(hovered_ability)
        return null

    director.set_cursor(cursor_type)
    return selected_card

func player_turn_process():
    var hovered_card = player_hand_process()

    if hovered_card != null and Input.is_action_just_pressed("mouse_button_left"):
        # Check if we can summon this card
        var can_summon = false
        if hovered_card.data.cost_type == CardData.CostType.NONE:
            can_summon = true
        elif hovered_card.data.cost_type == CardData.CostType.BLOOD:
            var blood_available = 0
            for board_card in player_board:
                if board_card == null:
                    continue
                blood_available += 1
                if board_card.has_ability(Ability.Name.WORTHY_SACRIFICE):
                    blood_available += 2
                if board_card.has_ability(Ability.Name.EGG):
                    blood_available -= 1
            if blood_available >= hovered_card.data.cost_amount:
                can_summon = true
        elif hovered_card.data.cost_type == CardData.CostType.BONE and player_bone_count >= hovered_card.data.cost_amount:
            can_summon = true

        # Check if there is space to summon this card
        var is_board_space_available = false
        for card in player_board:
            # Empty spaces count can be summoned onto
            if card == null:
                is_board_space_available = true
                break

            var card_will_reoccupy_slot = false
            if card.has_ability(Ability.Name.MANY_LIVES) and card.sacrifice_count < CAT_LIVES:
                card_will_reoccupy_slot = true
            if hovered_card.data.cost_type == CardData.CostType.BLOOD and not card_will_reoccupy_slot:
                is_board_space_available = true
                break
        if not is_board_space_available:
            can_summon = false

        # Begin summoning
        if can_summon:
            card_hover.close()
            hovered_card.animate_presummon()
            hovered_card.z_index = 1
            state = State.PLAYER_SUMMONING

            summoning_card = hovered_card
            if summoning_card.data.cost_type == CardData.CostType.NONE or summoning_card.data.cost_type == CardData.CostType.BONE:
                summoning_cost_met = true
            else:
                summoning_cost_met = false
        # Show can't summon message
        else:
            var message = ""
            if not is_board_space_available:
                message = "You have nowhere to place that."
            elif hovered_card.data.cost_type == CardData.CostType.BLOOD:
                message = "You need more sacrifices to summon that."
            elif hovered_card.data.cost_type == CardData.CostType.BONE:
                message = "You need more bones to summon that."
            popup.open(message, 1.0)

    var mouse_pos = get_viewport().get_mouse_position()
    if BELL_RECT.has_point(mouse_pos):
        if Input.is_action_just_pressed("mouse_button_left"):
            # COMBAT PHASE
            state = State.WAIT

            # Tell the opponent
            if network.network_is_connected():
                _on_opponent_ring_bell.rpc_id(network.opponent_id)

            # Ring the bell
            sfx_blip.play()
            bell.frame_coords.x = int(BellState.PRESS)
            var tween = get_tree().create_tween()
            tween.tween_interval(0.2)
            await tween.finished
            bell.frame_coords.x = int(BellState.DISABLED)

            # Do combat
            await combat_round(Turn.PLAYER)
            if is_game_over:
                return

            # Yield the turn
            if network.network_is_connected():
                popup.open("Opponent's turn.", 1.0)
                _on_opponent_yield_turn.rpc_id(network.opponent_id)
            else:
                state = State.PLAYER_TURN
            return
        else:
            bell.frame_coords.x = int(BellState.HOVER)
    else:
        bell.frame_coords.x = int(BellState.READY)

# PLAYER DECK DRAw

func player_deck_draw_process():
    var selected_card = player_hand_process()

    if selected_card != null and Input.is_action_just_pressed("mouse_button_left"):
        state = State.WAIT
        # Tell opponent we drew a card
        if network.network_is_connected():
            _on_opponent_draw_card.rpc_id(network.opponent_id)
        # Place the card in our hand
        player_deck_hand.erase(selected_card)
        for card in player_deck_hand:
            card.visible = false
            card.queue_free()
        player_deck_hand = []
        player_deck.erase(selected_card.card_id)
        player_hand.push_back(selected_card)

        # Shuffle the deck
        var unshuffled_deck = []
        while not player_deck.is_empty():
            unshuffled_deck.push_back(player_deck.pop_front())
        while not unshuffled_deck.is_empty():
            player_deck.push_back(unshuffled_deck.pop_at(randi_range(0, unshuffled_deck.size() - 1)))
        ui_update_deck_counters()

        await hand_update_positions()
        player_deck_draw_finished.emit()

# PLAYER SUMMONING

func player_summoning_process():
    var cursor_type = director.CursorType.POINTER
    var mouse_pos = get_viewport().get_mouse_position()

    if Input.is_action_just_pressed("mouse_button_right") and summoning_blood_count == 0:
        state = State.WAIT
        summoning_card.animate_presummon_end()
        await hand_update_positions()
        summoning_card = null
        state = State.PLAYER_TURN
        return

    # HOVER CARDSLOTS
    var hovered_cardslot = null
    var hovered_cardslot_index = -1
    for i in range(0, player_cardslots.size()):
        # Don't allow players to summon onto an occupied slot
        if summoning_cost_met and player_board[i] != null:
            continue
        # Don't allow players to sacrifice an empty slot
        if not summoning_cost_met and summoning_card.data.cost_type == CardData.CostType.BLOOD and player_board[i] == null:
            continue
        # Don't allow players to sacrifice an egg
        if not summoning_cost_met and player_board[i].has_ability(Ability.Name.EGG):
            continue
        # Check if mouse is within cardslot
        var cardslot = player_cardslots[i]
        if Rect2(cardslot.global_position - (Card.CARD_SIZE * 0.5), Card.CARD_SIZE).has_point(mouse_pos):
            hovered_cardslot = cardslot
            hovered_cardslot_index = i
            # Open the card hover, but not if it's already in place
            if card_hover.visible and card_hover.position == cardslot.global_position:
                continue
            card_hover.open(cardslot.global_position)
    if hovered_cardslot == null and card_hover.visible:
        card_hover.close()

    # PLACE CREATURE
    if summoning_cost_met:
        if hovered_cardslot != null:
            cursor_type = director.CursorType.DROP
            if Input.is_action_just_pressed("mouse_button_left"):
                # SUMMON
                state = State.WAIT
                director.set_cursor(director.CursorType.POINTER)
                card_hover.close()
                summoning_card.animate_presummon_end()
                await player_summon_card(summoning_card, hovered_cardslot_index, true)
                summoning_card = null
                state = State.PLAYER_TURN
                return
    # SACRIFICE CREATURE
    elif summoning_card.data.cost_type == CardData.CostType.BLOOD:
        if hovered_cardslot != null:
            cursor_type = director.CursorType.KNIFE
            if Input.is_action_just_pressed("mouse_button_left"):
                # PERFORM SACRIFICE
                state = State.WAIT
                if network.network_is_connected():
                    _on_opponent_sacrifice_card.rpc_id(network.opponent_id, hovered_cardslot_index)
                director.set_cursor(director.CursorType.POINTER)
                card_hover.close()
                summoning_blood_count += 1
                summoning_blood_count_this_turn += 1
                if player_board[hovered_cardslot_index].has_ability(Ability.Name.WORTHY_SACRIFICE):
                    summoning_blood_count += 2
                    summoning_blood_count_this_turn += 2
                if player_board[hovered_cardslot_index].has_ability(Ability.Name.MORSEL):
                    summoning_card.give_morsel(player_board[hovered_cardslot_index].base_power, player_board[hovered_cardslot_index].base_health)
                    summoning_card.card_refresh()
                await board_kill_card(Turn.PLAYER, hovered_cardslot_index, true)
                summoning_cost_met = summoning_blood_count >= summoning_card.data.cost_amount
                ui_update_blood_counter()
                state = State.PLAYER_SUMMONING
                return

    director.set_cursor(cursor_type)

# RULEBOOK

func rulebook_open(ability_name: Ability.Name):
    rulebook_name_label.text = Ability.name_str(ability_name)
    rulebook_desc_label.text = Ability.DESC[ability_name]
    rulebook_icon.texture = Ability.load_icon(ability_name)
    rulebook.visible = true

func rulebook_close():
    rulebook.visible = false

func rulebook_process():
    director.set_cursor(director.CursorType.POINTER)
    if Input.is_action_just_pressed("mouse_button_left"):
        rulebook_close()

# COMBAT

func combat_round(turn: Turn):
    if skip_combat:
        skip_combat = false
        return

    var lane_indices = range(0, 4) if turn == Turn.PLAYER else range(3, -1, -1)
    var attacker_board = player_board if turn == Turn.PLAYER else opponent_board
    var defender_board = opponent_board if turn == Turn.PLAYER else player_board
    var opponent_turn = Turn.OPPONENT if turn == Turn.PLAYER else Turn.PLAYER

    var combat_damage = 0
    for lane_index in lane_indices:
        # Determine attacker
        var attacker = attacker_board[lane_index]
        if attacker == null:
            continue
        if attacker.power == 0:
            continue

        # Determine attack indices
        var attack_indices = [lane_index]
        if attacker.has_ability(Ability.Name.TWIN_STRIKE):
            attack_indices = [lane_index - 1, lane_index + 1] if turn == Turn.PLAYER else [lane_index + 1, lane_index - 1]
        elif attacker.has_ability(Ability.Name.TRIPLET_STRIKE):
            attack_indices = [lane_index - 1, lane_index, lane_index + 1] if turn == Turn.PLAYER else [lane_index + 1, lane_index, lane_index - 1]
        elif attacker.has_ability(Ability.Name.DOUBLE_STRIKE):
            attack_indices = [lane_index, lane_index]
        # Attack at each index
        for attack_index in attack_indices:
            if attack_index < 0 or attack_index >= 4:
                continue

            await on_card_is_about_to_attack(turn, attacker, attack_index)

            var defender = defender_board[attack_index]
            if defender != null and attacker.has_ability(Ability.Name.AIRBORNE) and not defender.has_ability(Ability.Name.MIGHTY_LEAP):
                defender = null

            combat_damage = combat_damage + (await combat_do_attack(turn, attacker, attack_index, defender))
            if defender != null:
                await on_card_hit(opponent_turn, defender, attack_index, attacker)
                if defender.health == 0 or attacker.has_ability(Ability.Name.DEATHTOUCH):
                    attacker.kill_count += 1
                    await board_kill_card(opponent_turn, attack_index)
            # Handle death from porcupine
            if attacker.health == 0:
                await board_kill_card(turn, lane_index)
                break
    
    # Update score
    for i in range(0, combat_damage):
        # Increment score
        if turn == Turn.PLAYER:
            player_score += 1
        else:
            opponent_score += 1

        # Update scale
        score_scale.display_scores(opponent_score, player_score)

        # Delay for suspense
        var tween = get_tree().create_tween()
        tween.tween_interval(0.1)
        await tween.finished

    await check_if_candle_snuffed(turn)
    if is_game_over:
        return

    await on_combat_over(turn)

func check_if_candle_snuffed(turn: Turn):
    # Check if a candle is to be snuffed
    var score = min(abs(player_score - opponent_score), score_scale.SCORE_LIMIT)
    if score == score_scale.SCORE_LIMIT:
        # Delay for suspense
        var tween3 = get_tree().create_tween()
        tween3.tween_interval(1.0)
        await tween3.finished

        # Snuff the candle
        var candles = opponent_candles if turn == Turn.PLAYER else player_candles
        candles.snuff_candle()
        
        # Delay for suspense
        var tween2 = get_tree().create_tween()
        tween2.tween_interval(0.25)
        await tween2.finished

        if candles.no_candles_left():
            # End the game
            sfx_win.play()
            var message = "You win!" if turn == Turn.PLAYER else "You lose."
            popup.open(message)
            set_game_over()
        else:
            # Reset the scale
            sfx_scale.play()
            player_score = 0
            opponent_score = 0
            score_scale.display_scores(0, 0)

            # Give the defeated the smoke
            if turn == Turn.PLAYER:
                await opponent_hand_add_card()
            else:
                await hand_add_card(Card.THE_SMOKE)

func combat_attack_animation_play(at_position: Vector2):
    attack_animation.position = at_position
    attack_animation.visible = true
    attack_animation.play()
    sfx_attack.play()
    await attack_animation.animation_finished
    var fade_tween = get_tree().create_tween()
    fade_tween.tween_property(attack_animation, "modulate", Color(attack_animation.modulate.r, attack_animation.modulate.g, attack_animation.modulate.b, 0.0), 0.1)
    await fade_tween.finished
    attack_animation.visible = false
    attack_animation.modulate.a = 1.0

func combat_do_attack(turn: Turn, attacker: Card, index: int, defender):
    var defender_cardslots = opponent_cardslots if turn == Turn.PLAYER else player_cardslots

    var attacker_position = attacker.position
    var lunge_direction = attacker.position.direction_to(defender_cardslots[index].global_position)
    var added_score = 0

    # Attacker lunge
    var attack_tween = get_tree().create_tween()
    attack_tween.tween_property(attacker, "position", attacker_position + (-4 * lunge_direction), 0.1)
    attack_tween.tween_property(attacker, "position", attacker_position + (18 * lunge_direction), 0.25)
    await attack_tween.finished

    # Attacker return
    var return_tween = get_tree().create_tween()
    return_tween.tween_property(attacker, "position", attacker_position, 0.125)
    return_tween.tween_property(attacker, "position", attacker_position + (8 * lunge_direction), 0.125)
    return_tween.tween_property(attacker, "position", attacker_position, 0.125)

    # Update health
    var defender_tween = null

    # Check if we should hit the defender
    var hit_defender = defender != null
    # Don't hit submerged creatures
    if hit_defender and defender.has_ability(Ability.Name.SUBMERGE):
        hit_defender = false
    # Don't hit armored creatures
    if hit_defender and defender.has_ability(Ability.Name.ARMORED):
        hit_defender = false
    # If the defender has LOOSE_TAIL, then we should not hit the defender unless they have nowhere to go
    if hit_defender and defender.has_ability(Ability.Name.LOOSE_TAIL):
        var defender_board = opponent_board if turn == Turn.PLAYER else player_board
        var free_index = -1
        var direction = 1
        if index + direction >= 0 and index + direction < defender_board.size() and defender_board[index + direction] == null:
            free_index = index + direction
        elif index - direction >= 0 and index - direction < defender_board.size() and defender_board[index - direction] == null:
            free_index = index - direction
        if free_index != -1:
            hit_defender = false

    if hit_defender:
        defender.health = max(defender.health - attacker.power, 0)
        defender.card_refresh()

        defender_tween = get_tree().create_tween()
        combat_attack_animation_play(defender.position)
        defender_tween.tween_property(defender.dim, "visible", true, 0.0)
        defender_tween.tween_property(defender, "position", defender.position + Vector2(4, 0), 0.1)
        defender_tween.tween_property(defender, "position", defender.position + Vector2(-4, 0), 0.2)
        defender_tween.tween_property(defender, "position", defender.position + Vector2(4, 0), 0.2)
        defender_tween.tween_property(defender, "position", defender.position, 0.1)
        defender_tween.tween_property(defender, "modulate", Color(1, 1, 1, 1), 0.0)
        defender_tween.tween_property(defender.dim, "visible", false, 0.0)
    elif defender == null:
        added_score = attacker.power

    # Await tweens
    await return_tween.finished
    if defender_tween != null and defender_tween.is_running():
        await defender_tween.finished

    return added_score

# RPC

enum NetworkActionType {
    DRAW,
    NO_DRAW,
    SACRIFICE,
    SUMMON,
    BELL,
    YIELD,
    HOARDER
}

func network_process():
    if is_game_over:
        return
    if network_is_action_running:
        return
    if network_action_queue.is_empty():
        return

    var action = network_action_queue.pop_front()
    network_is_action_running = true
    if action.type == NetworkActionType.DRAW:
        if popup.visible:
            popup.close()
        await opponent_hand_add_card()
    elif action.type == NetworkActionType.NO_DRAW:
        await popup.open("Opponent's deck is empty. They take 1 damage.", 2.0)

        player_score += 1

        # Update scale
        score_scale.display_scores(opponent_score, player_score)

        # Delay for suspense
        var tween = get_tree().create_tween()
        tween.tween_interval(0.1)
        await tween.finished

        await check_if_candle_snuffed(Turn.OPPONENT)
        if is_game_over:
            return
    elif action.type == NetworkActionType.SACRIFICE:
        await board_kill_card(Turn.OPPONENT, 3 - action.index, true)
    elif action.type == NetworkActionType.SUMMON:
        await opponent_board_play_card(3 - action.index, action.card_id, action.eternal_counter, action.morsel_power, action.morsel_health, action.brood_parasite_roll)
    elif action.type == NetworkActionType.BELL:
        await combat_round(Turn.OPPONENT)
    elif action.type == NetworkActionType.YIELD:
        assert(network_action_queue.is_empty())
        popup.open("Your turn.", 1.0)
        state = State.PLAYER_DRAW
    elif action.type == NetworkActionType.HOARDER:
        popup.open("Opponent is choosing a card from their deck.")
    network_is_action_running = false

@rpc("any_peer", "reliable")
func _on_opponent_draw_card():
    network_action_queue.push_back({
        "type": NetworkActionType.DRAW
    })

@rpc("any_peer", "reliable")
func _on_opponent_cannot_draw_card():
    network_action_queue.push_back({
        "type": NetworkActionType.NO_DRAW
    })

@rpc("any_peer", "reliable")
func _on_opponent_sacrifice_card(index: int):
    network_action_queue.push_back({
        "type": NetworkActionType.SACRIFICE,
        "index": index
    })

@rpc("any_peer", "reliable")
func _on_opponent_place_card(index: int, card_id: int, eternal_counter: int, morsel_power: int, morsel_health: int, brood_parasite_roll: float):
    network_action_queue.push_back({
        "type": NetworkActionType.SUMMON,
        "index": index,
        "card_id": card_id,
        "eternal_counter": eternal_counter,
        "morsel_power": morsel_power,
        "morsel_health": morsel_health,
        "brood_parasite_roll": brood_parasite_roll
    })

@rpc("any_peer", "reliable")
func _on_opponent_ring_bell():
    network_action_queue.push_back({
        "type": NetworkActionType.BELL
    })

@rpc("any_peer", "reliable")
func _on_opponent_yield_turn():
    network_action_queue.push_back({
        "type": NetworkActionType.YIELD
    })

@rpc("any_peer", "reliable")
func _on_opponent_use_hoarder():
    network_action_queue.push_back({
        "type": NetworkActionType.HOARDER
    })

@rpc("any_peer", "reliable")
func _on_opponent_concede():
    sfx_win.play()
    popup.open("Your opponent conceded.")
    set_game_over()

func _on_opponent_disconnect():
    popup.open("Your opponent disconnected.")
    set_game_over()

func set_game_over():
    rulebook_close()
    is_game_over = true

func _on_player_concede():
    if network.network_is_connected():
        _on_opponent_concede.rpc_id(network.opponent_id)
    else:
        print("conceded but network disconnected?")
    sfx_win.play()
    popup.open("You conceded.")
    set_game_over()