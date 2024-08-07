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
require 'websocket-eventmachine-server'

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

$twitch = Twitch.new(@twitch_bot_id, $twitch_token_password)
$obs = OBS.new(@obs_password)
$godot = Godot.new()
$spotify = Spotify.new($twitch_token_password)

$clients = []


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
    end
  when 2
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status = $twitch.shoutout(name)
        $twitch.printResults(status)
    end
  when 3
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        rep = $twitch.getTwitchUser(name)
        $twitch.printResults(nil, rep)
    end
  when 4
    print('Enter the channel name: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.get_channel_info(name)
        $twitch.printResults(status, rep)
    end
  when 5
    print('Enter the title: ')
    title = gets.chomp
    if title != ""
        status = $twitch.change_stream_title(title)
        $twitch.printResults(status)
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
    end
  when 7
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.create_raid(name)
        $twitch.printResults(status, rep)
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
    end
  when 12
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.unban_user(name)
        $twitch.printResults(status, rep)
    end
  when 13
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status = $twitch.add_vip(name)
        $twitch.printResults(status)
    end
  when 14
    print('Enter the username: ')
    name = gets.chomp
    if name != ""
        status = $twitch.remove_vip(name)
        $twitch.printResults(status)
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
    end
  when 18
    print('Enter the channel name: ')
    name = gets.chomp
    if name != ""
        status, rep = $twitch.get_channel_badge(name)
        $twitch.printResults(status, rep)
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
      $spotify.getQueue()
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

def treat_twitch_commands(data)
  first_frag = data["payload"]["event"]["message"]["fragments"][0]
    if first_frag["type"] == "text"
      words = first_frag["text"].split(" ")
      case words[0]
      when "!color"
          color = words[1]
          if color.match?(/^#[0-9A-F]{6}$/i)
              color = color.delete_prefix("#")
              $godot.change_color2(color)
          end
      when "!rainbow"
        $godot.rainbow_on_off()
      when "!dum"
        $godot.dum_on_off()
      when "!discord"
        $twitch.send_message("venorrak", "empty discord server: https://discord.gg/ydJ7NCc8XM")
      when "!commands"
        $twitch.send_message("venorrak", "Commands: !color #ffffff, !rainbow, !dum, !song, !commands")
      when "!c"
        $twitch.send_message("venorrak", "Commands: !color #ffffff, !rainbow, !dum, !song, !commands")
      when "!song"
        $spotify.sendToAll({"type": "show"}.to_json, $clients)
      end
  end
end

Thread.start do
  loop do
      sleep(7000)
      $twitch.getAccess()
  end
end

Thread.start do
  loop do
      sleep(60)
      $spotify.getAccess()
  end
end

Thread.start do
  EM.run {
      ws = Faye::WebSocket::Client.new('wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30')

      ws.on :open do |event|
        #p [:open]
      end

      ws.on :message do |event|
          #data = [:message, event.data]
          data = JSON.parse(event.data)
          #ap data
          if data["metadata"]["message_type"] == "session_welcome"
              subscriptions = [
                  {"type": "channel.follow", "version": "2"},
                  {"type": "channel.ad_break.begin", "version": "1"},
                  {"type": "channel.chat.message", "version": "1"},
                  {"type": "channel.subscribe", "version": "1"},
                  {"type": "channel.subscription.gift", "version": "1"},
                  {"type": "channel.subscription.message", "version": "1"},
                  {"type": "channel.cheer", "version": "1"},
                  {"type": "channel.raid", "version": "1"}
              ]
              subscriptions.each do |sub|
                rep = $twitch.subscribeToEventSub(data["payload"]["session"]["id"], sub)
              end
              #subscibe_to_jake_chat(data["payload"]["session"]["id"])
          end
          if data["metadata"]["message_type"] == "notification"
              case data["payload"]["subscription"]["type"]
              when "channel.follow"
                  msg = {
                      "name": "Follow",
                      "name_color": "#ffd000",
                      "message": [
                        {
                          "type": "text",
                          "content": "#{data["payload"]["event"]["user_name"]} has followed"
                        }
                      ],
                      "type": "notif"
                  }
                  $twitch.writeToJSON(msg)

              when "channel.chat.message"
                  message = []
                  data["payload"]["event"]["message"]["fragments"].each do |frag|
                      if frag["type"] == "text"
                          message.push({
                              "type": "text",
                              "content": frag["text"]
                          })
                      elsif frag["type"] == "emote"
                          message.push({
                              "type": "emote",
                              "id": frag["emote"]["id"]
                          })
                      else
                          message.push({
                              "type": "text",
                              "content": frag["text"]
                          })
                      end
                  end
                  registered = false
                  pfp_url = ""
                  list = JSON.parse(File.read(File.join(__dir__, "chat/pfp.json")))
                  list.each do |pfp|
                      if pfp["name"] == data["payload"]["event"]["chatter_user_login"]
                          registered = true
                          pfp_url = pfp["url"]
                          break
                      end
                  end
                  if registered == false
                      pfp_url = $twitch.getTwitchUser(data["payload"]["event"]["chatter_user_login"])["data"][0]["profile_image_url"]
                      list.push({
                          "name": data["payload"]["event"]["chatter_user_login"],
                          "url": pfp_url
                      })
                      File.write("chat/pfp.json", list.to_json)
                  end

                  msg = {
                      "name": data["payload"]["event"]["chatter_user_name"],
                      "name_color": data["payload"]["event"]["color"],
                      "profile_image_url": pfp_url,
                      "message": message,
                      "type": "default"
                  }
                  $twitch.writeToJSON(msg)
                  treat_twitch_commands(data)
                  #jake_ror2(data)

              when "channel.ad_break.begin"
                  msg = {
                      "name": "Ad Break",
                      "name_color": "#ff0000",
                      "message": [
                        {
                          "type": "text",
                          "content": "ads playing for #{data["payload"]["event"]["duration_seconds"]} seconds"
                        }
                      ],
                      "type": "negatif"
                  }
                  $twitch.writeToJSON(msg)

              when "channel.subscribe"
                  if data["event"]["is_gift"] == false
                      msg = {
                          "name": "Subscribe",
                          "name_color": "#00ff00",
                          "message": [
                            {
                              "type": "text",
                              "content": "#{data["payload"]["event"]["user_name"]} has subscribed"
                            }
                          ],
                          "type": "subscribe"
                      }
                      $twitch.writeToJSON(msg)
                  end
              
              when "channel.subscription.gift"
                  if data["event"]["is_anonymous"] == false
                      msg = {
                          "name": "Gift Sub",
                          "name_color": "#00ff00",
                          "message": [
                            {
                              "type": "text",
                              "content": "anonymous has gifted #{data["payload"]["event"]["total"]} subs"
                            }
                          ],
                          "type": "subscribe"
                      }
                  else
                      msg = {
                          "name": "Gift Sub",
                          "name_color": "#00ff00",
                          "message": [
                            {
                              "type": "text",
                              "content": "#{data["payload"]["event"]["gifter_name"]} has gifted #{data["payload"]["event"]["total"]} subs"
                            }
                          ],
                          "type": "subscribe"
                      }
                  end
                  $twitch.writeToJSON(msg)

              when "channel.subscription.message"
                  msg = {
                      "name": "Resub",
                      "name_color": "#00ff00",
                      "message": [
                        {
                          "type": "text",
                          "content": "#{data["payload"]["event"]["user_name"]} has resubscribed :\n #{data["payload"]["event"]["message"]["text"]}"
                        }
                      ],
                      "type": "subscibe"
                  }
                  $twitch.writeToJSON(msg)

              when "channel.cheer"
                  if data["event"]["is_anonymous"] == false
                      msg = {
                          "name": "Cheers",
                          "name_color": "#e100ff",
                          "message": [{
                              "type": "text",
                              "content": "#{data["payload"]["event"]["user_name"]} has cheered #{data["payload"]["event"]["bits"]} bits"
                          }],
                          "type": "cheer"
                      }
                  else
                      msg = {
                          "name": "Cheers",
                          "name_color": "#e100ff",
                          "message": [
                            {
                              "type": "text",
                              "content": "anonymous has cheered #{data["payload"]["event"]["bits"]} bits"
                            }
                          ],
                          "type": "cheer"
                      }
                  end
                  $twitch.writeToJSON(msg)

              when "channel.raid"
                  msg = {
                      "name": "Raid",
                      "name_color": "#00ccff",
                      "message": [
                        {
                          "type": "text",
                          "content": "#{data["payload"]["event"]["from_broadcaster_user_name"]} has raided with #{data["payload"]["event"]["viewers"]} viewers !"
                        }
                      ],
                      "type": "raid"
                  }
                  $twitch.writeToJSON(msg)
              end
          end
      end

      ws.on :close do |event|
        #p [:close, event.code, event.reason, "twitch"]
      end
  }
end

Thread.start do
  EM.run do
    WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 5962) do |ws|
      ws.onopen do
        $clients << ws
        playback = $spotify.getPlaybackState()
        data = {
          "type" => "song",
          "name" => playback["item"]["name"],
          "artist" => playback["item"]["artists"][0]["name"],
          "image" => playback["item"]["album"]["images"][0]["url"],
          "progress_ms" => playback["progress_ms"],
          "duration_ms" => playback["item"]["duration_ms"]
        }
        $spotify.sendToAll(data.to_json, $clients)
      end

      ws.onmessage do |msg|
        p msg
      end

      ws.onclose do
        $clients.delete(ws)
        ws.close
      end

      ws.onerror do |error|
        puts "Error: #{error}"
      end
    end
  end
end

main_menu()