require "bundler/inline"
require "json"
require "socket"
require "date"
require 'faye/websocket'
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require "base64"
require "digest"
require "securerandom"
require 'timeout'

gemfile do
  source "https://rubygems.org"
  gem "faraday"
end

require "faraday"
require_relative "secret.rb"
require_relative "twitch_class.rb"
require_relative "obs_class.rb"
require_relative "godot_class.rb"
require_relative "spotify_class.rb"

$myServer = Faraday.new(url: "http://192.168.0.16:9898") do |conn|
  conn.request :url_encoded
end

$bus = nil

$twitch = Twitch.new(@twitch_bot_id, $twitch_token_password, $myServer)
$obs = OBS.new(@obs_password)
$godot = Godot.new()
$spotify = Spotify.new($twitch_token_password, $myServer)

def twitch_menu()
  choices = [
    "send message",
    "shoutout",
    "get user data",
    "get channel data",
    "change stream title",
    "create announcement",
    "create raid",
    "cancel raid",
    "start commercial",
    "snooze ad",
    "ban user",
    "unban user",
    "add vip",
    "remove vip",
    "get channel followers",
    "get viewers",
    "get channel emotes",
    "get channel badges",
    "get global emotes",
    "get global badges",
    "back to main menu"
  ]
  system('clear')
  choices.each_with_index do |choice, index|
    puts("#{index + 1}. #{choice}")
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  case choice
  when 1
    print('Enter message: ')
    message = gets.chomp
    print('Enter channel: ')
    channel = gets.chomp
    if message != "" && channel != ""
        status, rep = $twitch.send_message(channel, message)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 2
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status = $twitch.shoutout(name)
        $twitch.printResults(status)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 3
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        rep = $twitch.getTwitchUser(name)
        $twitch.printResults(nil, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 4
    print('Enter the channel name: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.get_channel_info(name)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 5
    print('Enter the title: ')
    title = gets.chomp
    if title != ""
        status = $twitch.change_stream_title(title)
        $twitch.printResults(status)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 6
    print('Enter the message (exit to abort): ')
    message = ""
    until message.length > 0 && message.length < 500 || message == "exit"
        message = gets.chomp
    end
    if message != "exit"
        status = $twitch.create_announcement(message)
        $twitch.printResults(status)
    else
        puts('Aborted')
        sleep(1)
        twitch_menu()
    end
  when 7
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.create_raid(name)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 8
    status = $twitch.cancel_raid()
    $twitch.printResults(status)
  when 9
    print('Enter the length of the commercial (secs, max 180): ')
    length = gets.chomp.to_i
    if length != 0
        status, rep = $twitch.start_commercial(length)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 10
    status, rep = $twitch.snooze_ad()
    $twitch.printResults(status, rep)
  when 11
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
      print('Enter the duration (mins, 0 = permanent): ')
      duration = gets.chomp.to_i
      print('Enter the reason (optional = ""): ')
      reason = gets.chomp
      if reason == ""
          reason = nil
      end
      status, rep = $twitch.ban_user(name, duration, reason)
      $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 12
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.unban_user(name)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 13
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status = $twitch.add_vip(name)
        $twitch.printResults(status)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 14
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status = $twitch.remove_vip(name)
        $twitch.printResults(status)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 15
    print('Enter the channel name: ')
    name = gets.chomp
    if name != ""
        print('Enter the user name (optional = ""): ')
        user = gets.chomp
        if user == ""
            user = nil
        end
        status, rep = $twitch.get_channel_follow(name, user)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 16
    status, rep = $twitch.get_viewers()
    $twitch.printResults(status, rep)
  when 17
    print('Enter the channel name: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.get_channel_emotes(name)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 18
    print('Enter the channel name: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.get_channel_badge(name)
        $twitch.printResults(status, rep)
    else
      puts "cancelled"
      sleep(1)
      twitch_menu()
    end
  when 19
    status, rep = $twitch.get_global_emotes()
    $twitch.printResults(status, rep)
  when 20
    status, rep = $twitch.get_global_badges()
    $twitch.printResults(status, rep)
  when 21
    main_menu()
  else
    puts('Invalid choice')
    sleep(1)
    twitch_menu()
  end
end

def obs_menu()
  system('clear')
  choices = [
      "mute mic",
      "set current scene",
      "set item invisible",
      "set item visible",
      'back'
  ]
  choices.each_with_index do |choice, index|
      puts "#{index + 1}. #{choice}"
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  case choice
  when 1
    $obs.obs_request(:get_inputs, nil)
    sleep(0.5)
    mic_uuid = ""
    inputs = $obs.get_data()
    if inputs != nil
      inputs["d"]["responseData"]["inputs"].each do |input|
        if input["inputName"] == "Mic/Aux"
          mic_uuid = input["inputUuid"]
        end
      end
      $obs.obs_request(:mute_input, [mic_uuid, $obs.get_mic_muted()])
      $obs.set_mic_muted(!$obs.get_mic_muted())
      $obs.process_data(true)
    else
      puts('OBS server is not running')
      sleep 1
    end
    obs_menu()
  when 2
    $obs.obs_request(:get_scene_list, nil)
    sleep(0.5)
    scenes = $obs.get_data()
    if scenes != nil
      scenes["d"]["responseData"]["scenes"].each do |scene|
        p scene["sceneName"]
      end
      print('Choose a scene: ')
      scene = gets.chomp
      $obs.obs_request(:set_current_scene, [scene])
      $obs.process_data()
    else
      puts('OBS server is not running')
      sleep 1
    end
    obs_menu()
  when 3
    $obs.obs_request(:get_scene_list, nil)
    sleep(0.5)
    scenes = $obs.get_data()
    if scenes != nil
      scenes["d"]["responseData"]["scenes"].each do |scene|
        p scene["sceneName"]
      end
      print('Choose a scene: ')
      scene = gets.chomp
      $obs.obs_request(:get_item_list, [scene])
      sleep(0.5)
      items = $obs.get_data()
      if items != nil
        items["d"]["responseData"]["sceneItems"].each do |item|
          p item["sourceName"]
        end
        puts "choose an item"
        item = gets.chomp
        $obs.obs_request(:get_item_id, [item, scene])
        sleep(0.5)
        begin
          item_id = $obs.get_data()["d"]["responseData"]["sceneItemId"]
          $obs.obs_request(:set_item_invisible, [scene, item_id])
          $obs.process_data(false)
        end
      end
    else
      puts('OBS server is not running')
      sleep 1
    end
    obs_menu()
  when 4
    $obs.obs_request(:get_scene_list, nil)
    sleep(0.5)
    scenes = $obs.get_data()
    if scenes != nil
      scenes["d"]["responseData"]["scenes"].each do |scene|
        p scene["sceneName"]
      end
      puts "choose a scene"
      scene = gets.chomp
      $obs.obs_request(:get_item_list, [scene])
      sleep(0.5)
      items = $obs.get_data()
      if items != nil
        items["d"]["responseData"]["sceneItems"].each do |item|
          p item["sourceName"]
        end
        puts "choose an item"
        item = gets.chomp
        $obs.obs_request(:get_item_id, [item, scene])
        sleep(0.5)
        begin
          item_id = $obs.get_data()["d"]["responseData"]["sceneItemId"]
          $obs.obs_request(:set_item_visible, [scene, item_id])
          $obs.process_data(false)
        end
      end
    end
    obs_menu()
  when 5
    main_menu()
  else
    puts('Invalid choice')
    sleep(1)
    obs_menu()
  end
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
    'zoom_on_off',
    'back'
  ]
  choices.each_with_index do |choice, index|
    puts("#{index + 1}. #{choice}")
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  case choice
  when 1
    $godot.freeze_unfreeze_head()
    godot_menu()
  when 2
    $godot.reset_head()
    godot_menu()
  when 3
    $godot.change_color()
    godot_menu()
  when 4
    $godot.rainbow_on_off()
    godot_menu()
  when 5
    $godot.set_head_tiny()
    godot_menu()
  when 6
    $godot.set_head_normal()
    godot_menu()
  when 7
    $godot.green_screen_on_off()
    godot_menu()
  when 8
    $godot.reset_godot_connection()
    $godot.do_sleep()
    godot_menu()
  when 9
    $godot.dum_on_off()
    godot_menu()
  when 10
    $godot.brb_on_off()
    godot_menu()
  when 11
    $godot.starting_on_off()
    godot_menu()
  when 12
    $godot.zoom_on_off()
    godot_menu()
  when 13
    main_menu()
  else
    puts('Invalid choice')
    $godot.do_sleep()
    godot_menu()
  end
end

def main_menu()
  choices = [
      "godot",
      "twitch",
      "obs",
      "spotify",
      "test_ws",
      "exit"
  ]
  system('clear')
  choices.each_with_index do |choice, index|
      puts("#{index + 1}. #{choice}")
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  case choice
  when 1
    godot_menu()
  when 2
    twitch_menu()
  when 3
    obs_menu()
  when 4
    spotify_menu()
  when 5
    p "sending test message"
    $bus.send({to: "BUS", from: "cli", payload: {type: "test"}}.to_json)
    sleep(1)
    main_menu()
  when 6
    exit
  else
    puts('Invalid choice')
    sleep(1)
    main_menu()
  end
end

def spotify_menu()
  choices = [
      'get playback state',
      "resume track",
      "pause track",
      "skip track",
      "previous track",
      "set volume",
      "get queue",
      "add track to queue",
      "back"
  ]
  system('clear')
  choices.each_with_index do |choice, index|
      puts("#{index + 1}. #{choice}")
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  begin
    case choice
    when 1
      ap $spotify.getPlaybackState()
      gets
      spotify_menu()
    when 2
      $spotify.resumeTrack()
      gets
      spotify_menu()
    when 3
      $spotify.pauseTrack()
      gets
      spotify_menu()
    when 4
      $spotify.skipTrack()
      gets
      spotify_menu()
    when 5
      $spotify.previousTrack()
      gets
      spotify_menu()
    when 6
      print('Enter volume: ')
      volume = gets.chomp.to_i
      $spotify.setVolume(volume)
      gets
      spotify_menu()
    when 7 
      ap $spotify.getQueue()
      gets
      spotify_menu()
    when 8
      print('Enter url: ')
      url = gets.chomp
      uri = getUriFromUrl(url)
      if uri != nil
        if $spotify.isThisARealSong(uri)
          $spotify.addTrackToQueue(uri)
        else
          puts('Invalid song')
        end
      else
        puts('Invalid url')
      end
      gets
      spotify_menu()
    when 9
      main_menu()
    else
        puts('Invalid choice')
        sleep(1)
        spotify_menu()
    end
  
  rescue => exception
    puts(exception)
    $spotify.getAccess()
    spotify_menu()
  end
end

Thread.start do
  EM.run do
    bus = Faye::WebSocket::Client.new('ws://192.168.0.16:5963')

    bus.on :open do |event|
      p [:open, "BUS"]
      $bus = bus
    end

    bus.on :message do |event|
      begin
        data = JSON.parse(event.data)
      rescue
        data = event.data
      end
      if data["to"] == "cli" && data["from"] == "BUS"
        if data["payload"]["type"] == "token_refreshed"
          p "token refreshing"
          case data["payload"]["client"]
          when "twitch"
            $twitch.getAccess()
          when "spotify"
            $spotify.getAccess()
          end
        end
      end
    end

    bus.on :error do |event|
      p [:error, event.message, "BUS"]
    end

    bus.on :close do |event|
      p [:close, event.code, event.reason, "BUS"]
    end
  end
end

main_menu()