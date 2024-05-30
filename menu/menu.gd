extends Node2D

@onready var network = get_node("/root/Network")

@onready var main_cluster = $main_cluster
@onready var name_edit = $main_cluster/name/edit
@onready var warn_label = $main_cluster/warn
@onready var warn_label_timer = $main_cluster/warn/hide_timer
@onready var host_button = $main_cluster/host_button
@onready var join_button = $main_cluster/join_button

@onready var host_cluster = $host_cluster
@onready var host_status = $host_cluster/status
@onready var host_back_button = $host_cluster/back_button
@onready var host_yes_button = $host_cluster/yes_button
@onready var host_no_button = $host_cluster/no_button

@onready var join_cluster = $join_cluster
@onready var ip_label = $join_cluster/ip
@onready var ip_edit = $join_cluster/ip/edit
@onready var join_warn_label = $join_cluster/warn
@onready var join_warn_label_timer = $join_cluster/warn/hide_timer
@onready var join_back_button = $join_cluster/back_button
@onready var join_connect_button = $join_cluster/connect_button
@onready var join_connect_status = $join_cluster/status
@onready var join_connect_back_button = $join_cluster/connect_back_button

var local_ip: String

func _ready():
    if OS.has_feature("windows") and OS.has_environment("COMPUTERNAME"):
        local_ip = IP.resolve_hostname(str(OS.get_environment("COMPUTERNAME")), 1)
    if (OS.has_feature("x11") or OS.has_feature("OSX")) and OS.has_environment("HOSTNAME"):
        local_ip = IP.resolve_hostname(str(OS.get_environment("HOSTNAME")), 1)

    host_button.pressed.connect(_on_host_button_pressed)
    join_button.pressed.connect(_on_join_button_pressed)
    warn_label_timer.timeout.connect(_on_warn_label_timer_timeout)
    host_back_button.pressed.connect(_on_host_back_button_pressed)
    join_back_button.pressed.connect(_on_join_back_button_pressed)
    join_connect_button.pressed.connect(_on_join_connect_button_pressed)
    join_warn_label_timer.timeout.connect(_on_join_warn_timer_timeout)
    join_connect_back_button.pressed.connect(_on_join_connect_back_button_pressed)

    open_main_cluster()

func update_username():
    network.player.name = name_edit.text

func open_main_cluster():
    main_cluster.visible = true
    host_cluster.visible = false
    join_cluster.visible = false

func _on_warn_label_timer_timeout():
    warn_label.visible = false

func show_warning():
    warn_label.text = "Please enter a name."
    warn_label.visible = true
    warn_label_timer.start(1.0)

func _on_host_button_pressed():
    if not main_cluster.visible:
        return
    if name_edit.text == "":
        show_warning()
        return
    update_username()
    network.server_create()
    open_host_cluster()

func _on_join_button_pressed():
    if not main_cluster.visible:
        return
    if name_edit.text == "":
        show_warning()
        return
    update_username()
    open_join_cluster()

func _on_host_back_button_pressed():
    if not visible:
        return
    open_main_cluster()

func open_host_cluster():
    main_cluster.visible = false
    join_cluster.visible = false
    host_status.text = "Your IP is " + local_ip + "\nAwaiting an opponent..."
    host_cluster.visible = true
    host_back_button.visible = true
    host_yes_button.visible = false
    host_no_button.visible = false

func _on_join_warn_timer_timeout():
    join_warn_label.visible = false

func show_join_warning(text):
    join_warn_label.text = text 
    join_warn_label.visible = true
    join_warn_label_timer.start(1.0)

func open_join_cluster():
    main_cluster.visible = false
    host_cluster.visible = false

    join_connect_status.visible = false
    join_connect_back_button.visible = false

    join_connect_button.visible = true
    join_back_button.visible = true
    ip_label.visible = true
    join_cluster.visible = true

func _on_join_back_button_pressed():
    if not join_back_button.visible:
        return 
    open_main_cluster()

func _on_join_connect_back_button_pressed():
    if not join_connect_back_button.visible:
        return 
    open_join_cluster()

func _on_join_connect_button_pressed():
    if not join_connect_button.visible:
        return
    if not ip_edit.text.is_valid_ip_address():
        show_join_warning("Invalid IP address.")
        return
    var success = network.client_connect(ip_edit.text)
    if not success:
        show_join_warning("Connection failed.")
        return

    ip_label.visible = false
    join_connect_button.visible = false
    join_back_button.visible = false

    join_connect_status.text = "Connecting..."
    join_connect_status.visible = true
    join_connect_back_button.visible = true
