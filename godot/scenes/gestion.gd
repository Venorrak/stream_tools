extends Node3D

var done = false
var json = JSON.new()
var num_socket = 5555
@onready var head = $Tv
@onready var right_eye = $Tv/display/SubViewport/right_eye
@onready var left_eye = $Tv/display/SubViewport/left_eye
@onready var equaliser = $Tv/display/SubViewport/equaliser
@onready var green_screen = $Tv/display/SubViewport/green_screen
var server = TCPServer.new()
var clients = []
var equaliser_bars = []

func _ready():
	server.listen(num_socket, "127.0.0.1")
	var childrens = equaliser.find_children("right")[0].get_children()
	for i in len(childrens):
		equaliser_bars.append(childrens[i])
	childrens = equaliser.find_children("left")[0].get_children()
	for i in len(childrens):
		equaliser_bars.append(childrens[i])
	
func _process(delta):
	if server.is_connection_available():
		clients.append(server.take_connection())
	for client in clients:
		if client.get_status() == 2:
			var available_bytes = client.get_available_bytes()
			if available_bytes > 0:
				var data = client.get_partial_data(available_bytes)
				data = json.parse_string(str(data[1].get_string_from_utf8()))
				match data["command"]:
					"freeze_unfreeze_head":
						head.frozen = !head.frozen
					"reset_head":
						head.rotation = Vector3(0, 0, 0)
						right_eye.position = head.origin_right_eye_position
						right_eye.scale = head.origin_right_eye_scale
						left_eye.position = head.origin_left_eye_postion
						left_eye.scale = head.origin_left_eye_scale
						head.rainbow = false
						change_face_color("4e6fff")
					"change_color":
						change_face_color(data["data"])
					"rainbow_on_off":
						head.rainbow = !head.rainbow
					"scale_tiny":
						head.position.x = -4
					"scale_default":
						head.position.x = 0
					"green_on_off":
						green_screen.visible = !green_screen.visible
						head.rainbow = false
						
func change_face_color(couleur : Color):
	for i in len(equaliser_bars):
		equaliser_bars[i].color = couleur
		right_eye.modulate = couleur
		left_eye.modulate = couleur