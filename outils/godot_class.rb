class Godot
  def send_to_godot(message)
    data = {
      from: 'cli',
      to: 'avatar',
      time: Time.now().to_s.split(" ")[1],
      payload: message
    }
    $bus.send(data.to_json)
  end

  def do_sleep(x=1)
    sleep(x)
  end

  ##############################
  #       Godot functions      #
  ##############################

  def zoom_on_off()
    msg = {
      'command': 'zoom_in_out',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def starting_on_off()
    msg = {
      'command': 'starting_on_off',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def brb_on_off()
    msg = {
      'command': 'brb_on_off',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def freeze_unfreeze_head()
    msg = {
      'command': 'freeze_unfreeze_head',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def reset_head()
    msg = {
      'command': 'reset_head',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def change_color()
    print('Enter color: ')
    color = gets.chomp
    msg = {
      'command': 'change_color',
      'params': {},
      'data': color
    }
    send_to_godot(msg)
  end

  def change_color2(color)
    msg = {
      'command': 'change_color',
      'params': {},
      'data': color
    }
    send_to_godot(msg)
  end

  def rainbow_on_off()
    msg = {
      'command': 'rainbow_on_off',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def set_head_tiny()
    msg = {
      'command': 'scale_tiny',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def set_head_normal()
    msg = {
      'command': 'scale_default',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def green_screen_on_off()
    msg = {
      'command': 'green_on_off',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

  def dum_on_off()
    msg = {
      'command': 'dum_on_off',
      'params': {},
      'data': {}
    }
    send_to_godot(msg)
  end

end