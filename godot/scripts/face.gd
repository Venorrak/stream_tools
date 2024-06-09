extends Node3D
const point = preload("res://scenes/point.tscn")

var points = []
var done = false
var socket = PacketPeerUDP.new()
var num_socket = 12345
var json = JSON.new()

func _init():
	socket.bind(num_socket, "127.0.0.1", 8300)
	if(socket.is_socket_connected() != true):
		print("An error occurred listening on port 4242")
	else:
		done = true;
		print("Listening on port 12345 on localhost")
	for i in range(478):
		var newPoint = point.instantiate()
		add_child(newPoint)
		points.append(newPoint)
	print("finished")
	
# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if socket.get_available_packet_count() > 0:
		var pkt = socket.get_packet().get_string_from_ascii()
		pkt = json.parse_string(pkt)
		var origin = pkt[1]
		for i in range(478):
			var x = pkt[i][0] - origin[0]
			var y = pkt[i][1] - origin[1]
			var z = pkt[i][2] - origin[2]
			points[i].position.x = x
			points[i].position.y = y
