
class GodotCli
    def init()
        begin
            @godot_server = TCPSocket.new('127.0.0.1', 5555)
        rescue
            puts('Godot server is not running')
        end
    end

    def reset_connection()
        begin
            begin
                @godot_server.close()
            rescue
                puts('godot server is not connected')
            end
            @godot_server = TCPSocket.new('127.0.0.1', 5555)
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

    def menu()
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
        when 2
            reset_head()
        when 3
            change_color()
        when 4
            rainbow_on_off()
        when 5
            set_head_tiny()
        when 6
            set_head_normal()
        when 7
            green_screen_on_off()
        when 8
            reset_connection()
            do_sleep()
            menu()
        when 9
            dum_on_off()
        when 10
            brb_on_off()
        when 11
            starting_on_off()
        when 12
            main_menu()
        else
            puts('Invalid choice')
            do_sleep()
            menu()
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
        menu()
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
        menu()
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
        menu()
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
        menu()
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
        menu()
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
        menu()
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
        menu()
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
        menu()
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
        menu()
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
        menu()
    end
end

