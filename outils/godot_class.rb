class Godot

  def initialize
    begin
      Timeout::timeout(2) {
        @godot_server = TCPSocket.new('172.28.224.1', 5555)
      }
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
      @godot_server = TCPSocket.new('172.28.224.1', 5555)
    rescue
      puts('Godot server is not running')
    end
  end

  def send_to_godot(message)
    begin
      @godot_server.puts(message.to_json)
    rescue
      reset_godot_connection()
      @godot_server.puts(message.to_json)
    end
  end

  def do_sleep(x=1)
    sleep(x)
  end

  ##############################
  #       Godot functions      #
  ##############################

  def starting_on_off()
    if !@godot_server.nil?
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
      msg = {
        'command': 'dum_on_off',
        'params': {},
        'data': {}
      }
      send_to_godot(msg)
      do_sleep()
    end
  end

end