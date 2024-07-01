
def godot_init()
    begin
        @godot_server = TCPSocket.new('172.31.224.1', 5555)
    rescue
        puts('Godot server is not running')
    end
end

def reset_godot_connection()
    begin
        begin
            @godot_server.close()
        rescue
            puts('godot server is not connected')
        end
        @godot_server = TCPSocket.new('172.31.224.1', 5555)
    rescue
        puts('Godot server is not running')
    end
end

def send_to_godot(message)
    p message.to_json
    begin
        @godot_server.puts(message.to_json)
    rescue
        reset_connection()
        @godot_server.puts(message.to_json)
    end
end

def do_sleep(x=1)
    sleep(x)
end

def godot_menu()
    system('clear')
    choices = [
        'freeze/unfreeze head',
        'reset head',
        'change color',
        'rainbow_on_off',
        'set head tiny',
        'set head normal',
        'green_screen_on_off',
        'reset connection',
        'dum_on_off',
        'brb_on_off',
        'starting_on_off',
        'back'
    ]
    choices.each_with_index do |choice, index|
        puts("#{index + 1}. #{choice}")
    end
    print('Enter your choice: ')
    choice = gets.chomp.to_i
    case choice
    when 1
        freeze_unfreeze_head()
        godot_menu()
    when 2
        reset_head()
        godot_menu()
    when 3
        change_color()
        godot_menu()
    when 4
        rainbow_on_off()
        godot_menu()
    when 5
        set_head_tiny()
        godot_menu()
    when 6
        set_head_normal()
        godot_menu()
    when 7
        green_screen_on_off()
        godot_menu()
    when 8
        reset_godot_connection()
        do_sleep()
        godot_menu()
    when 9
        dum_on_off()
        godot_menu()
    when 10
        brb_on_off()
        godot_menu()
    when 11
        starting_on_off()
        godot_menu()
    when 12
        main_menu()
    else
        puts('Invalid choice')
        do_sleep()
        godot_menu()
    end
end

def starting_on_off()
    if !@godot_server.nil?
        puts('starting_on_off')
        msg = {
            'command': 'starting_on_off',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def brb_on_off()
    if !@godot_server.nil?
        puts('brb_on_off')
        msg = {
            'command': 'brb_on_off',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def freeze_unfreeze_head()
    if !@godot_server.nil?
        puts('freeze/unfreeze head')
        msg = {
            'command': 'freeze_unfreeze_head',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def reset_head()
    if !@godot_server.nil?
        puts('reset head')
        msg = {
            'command': 'reset_head',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def change_color()
    if !@godot_server.nil?
        puts('change color')
        print('Enter color: ')
        color = gets.chomp
        msg = {
            'command': 'change_color',
            'params': {},
            'data': color
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def change_color2(color)
    if !@godot_server.nil?
        puts('change color')
        msg = {
            'command': 'change_color',
            'params': {},
            'data': color
        }
        send_to_godot(msg)
    end
end

def rainbow_on_off()
    if !@godot_server.nil?
        puts('rainbow_on_off')
        msg = {
            'command': 'rainbow_on_off',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def set_head_tiny()
    if !@godot_server.nil?
        puts('set head tiny')
        msg = {
            'command': 'scale_tiny',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def set_head_normal()
    if !@godot_server.nil?
        puts('set head normal')
        msg = {
            'command': 'scale_default',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def green_screen_on_off()
    if !@godot_server.nil?
        puts('green_screen_on_off')
        msg = {
            'command': 'green_on_off',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

def dum_on_off()
    if !@godot_server.nil?
        puts('dum_on_off')
        msg = {
            'command': 'dum_on_off',
            'params': {},
            'data': {}
        }
        send_to_godot(msg)
        do_sleep()
    end
end

