require "bundler/inline"
require "json"
require 'faye/websocket'
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require "openssl"
require 'remove_emoji'

gemfile do
  source "https://rubygems.org"
  gem "faraday"
  gem "mysql2"
end

require "faraday"
require "mysql2"
require_relative "secret.rb"

$online = false
$bus = nil

$spotify_token = nil
$spotify_last_song_played = nil
$spotify_update_counter = 0

$twitch_token = nil
$me_twitch_id = nil

$points_last_refresh = AbsoluteTime.now
$points_users_last_scan = []

$acceptedJoels = ["GoldenJoel" , "Joel2" , "Joeler" , "Joel" , "jol" , "JoelCheck" , "JoelbutmywindowsXPiscrashing" , "JOELLINES", "Joeling", "Joeling", "LetHimJoel", "JoelPride", "WhoLetHimJoel", "Joelest", "EvilJoel", "JUSSY", "JoelJams", "JoelTrain", "BarrelJoel", "JoelWide1", "JoelWide2", "Joeling2"]

$TokenService = Faraday.new(url: "http://192.168.0.16:5002") do |conn|
  conn.request :url_encoded
end

$SQLService = Faraday.new(url: "http://192.168.0.16:5001")

$APItwitch = Faraday.new(url: "https://api.twitch.tv") do |conn|
  conn.request :url_encoded
end

$spotify_api_server = Faraday.new(url: "https://api.spotify.com") do |conn|
  conn.request :url_encoded
end

##### TWITCH #####

def getTwitchToken()
  begin
    response = $TokenService.get("/token/twitch") do |req|
      req.headers["Authorization"] = $twitch_safety_string
    end
    rep = JSON.parse(response.body)
    $twitch_token = rep["token"]
  rescue
    puts "Token Service is down"
  end
end

def subscribeToTwitchEventSub(session_id, type)
  data = {
      "type" => type[:type],
      "version" => type[:version],
      "condition" => {
          "broadcaster_user_id" => $me_twitch_id,
          "to_broadcaster_user_id" => $me_twitch_id,
          "user_id" => $me_twitch_id,
          "moderator_user_id" => $me_twitch_id
      },
      "transport" => {
          "method" => "websocket",
          "session_id" => session_id
      }
  }.to_json
  response = $APItwitch.post("/helix/eventsub/subscriptions", data) do |req|
      req.headers["Authorization"] = "Bearer #{$twitch_token}"
      req.headers["Client-Id"] = $twitch_bot_id
      req.headers["Content-Type"] = "application/json"
  end
  return JSON.parse(response.body)
end

def getTwitchUserId(username)
  begin
    response = $APItwitch.get("/helix/users?login=#{username}") do |req|
      req.headers["Authorization"] = "Bearer #{$twitch_token}"
      req.headers["Client-Id"] = $twitch_bot_id
    end
    rep = JSON.parse(response.body)
  rescue
    return nil
  end
  return rep["data"][0]["id"]
end

def getTwitchUserPFP(username)
  begin
    response = $APItwitch.get("/helix/users?login=#{username}") do |req|
      req.headers["Authorization"] = "Bearer #{$twitch_token}"
      req.headers["Client-Id"] = $twitch_bot_id
    end
    rep = JSON.parse(response.body)
  rescue
    return ""
  end
  begin
    return rep["data"][0]["profile_image_url"]
  rescue
    ap rep
    return "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fdivedigital.id%2Fwp-content%2Fuploads%2F2022%2F07%2F2-Blank-PFP-Icon-Instagram.jpg&f=1&nofb=1&ipt=a0b42ddbcd36b663a8af0c817aeb97394e66d999f6f6613150ed5cf9466123c8&ipo=images"
  end
end

def send_twitch_message(channel, message)
  begin
    channel_id = getTwitchUserId(channel)
    if channel == "venorrak"
      message = "[📺] #{message}"
    end
    request_body = {
        "broadcaster_id": channel_id,
        "sender_id": $me_twitch_id,
        "message": message
    }.to_json
    response = $APItwitch.post("/helix/chat/messages", request_body) do |req|
        req.headers["Authorization"] = "Bearer #{$twitch_token}"
        req.headers["Client-Id"] = $twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end
    p response.status
  rescue
    p "error sending message"
  end
end

def treat_twitch_commands(data)
  first_frag = data["payload"]["event"]["message"]["fragments"][0]
    if first_frag["type"] == "text"
      words = first_frag["text"].strip.split(" ")
      case words[0].downcase
      when "!color"
          color = words[1]
          if color != nil
            if color.match?(/^#[0-9A-F]{6}$/i)
              color = color.delete_prefix("#")
              msg = {
                'command': 'change_color',
                'params': {},
                'data': color
              }
              msg = createMSG("twitch", "avatar", msg)
              sendToBus(msg)
            end
          end
      when "!rainbow"
        msg = {
          'command': 'rainbow_on_off',
          'params': {},
          'data': {}
        }
        msg = createMSG("twitch", "avatar", msg)
        sendToBus(msg)
      when "!dum"
        msg = {
          'command': 'dum_on_off',
          'params': {},
          'data': {}
        }
        msg = createMSG("twitch", "avatar", msg)
        sendToBus(msg)
      when "!discord"
        send_twitch_message("venorrak", "Join the discord server: https://discord.gg/ydJ7NCc8XM")
        send_twitch_message("venorrak", "You can see me talking on prod's discord server: https://discord.gg/JzPgeMp3EV or on Jake's discord server: https://discord.gg/MRjMmxQ6Wb")
      when "!commands"
        send_twitch_message("venorrak", "Commands: !discord, !color #ffffff, !rainbow, !dum, !song, !JoelCommands")
      when "!c"
        send_twitch_message("venorrak", "Commands: !discord, !color #ffffff, !rainbow, !dum, !song, !JoelCommands")
      when "!song"
        playback = getSpotidyPlaybackState()
        music_link = playback["item"]["external_urls"]["spotify"]
        playlist_link = playback["context"]["external_urls"]["spotify"]
        send_twitch_message("venorrak", "Currently playing: #{music_link}. Listen to the playlist here: #{playlist_link}")

        msg = {
          "type": "show"
        }
        msg = createMSG("twitch", "spotifyOverlay", msg)
        sendToBus(msg)
        $spotify_update_counter = 11
      when "!lore"
        if words[1] != nil
          lore = $sqlGetLore.execute(words[1]).first
          if lore.nil?
            send_twitch_message("venorrak", "No lore for this word")
          else
            send_twitch_message("venorrak", "Lore for #{words[1]}: #{lore["count"]}")
          end
        else
          send_twitch_message("venorrak", "No word specified")
        end
      end
  end
end

def treatForLore(messageData)
  textContent = messageData["payload"]["event"]["message"]["text"].strip.downcase
  words = textContent.split(" ")
  words.each do |word|
    sanitizedWord = RemoveEmoji::Sanitize.call(word).delete_suffix("\u{E0000}")
    lore = sendQuery("GetLore", [sanitizedWord])
    if lore.nil?
      sendQuery("NewLore", [sanitizedWord])
    else
      sendQuery("UpdateLore", [sanitizedWord])
    end
  end
end

def calculateLoreScore(messageData)
  textContent = messageData["payload"]["event"]["message"]["text"].strip.downcase
  highestScore = sendQuery("GetHighestLore", [])["count"]
  words = textContent.split(" ")
  score = 0
  words.each do |word|
    sanitizedWord = RemoveEmoji::Sanitize.call(word).delete_suffix("\u{E0000}")
    if sanitizedWord != ""
      lore = sendQuery("GetLore", [sanitizedWord])
    end
    if !lore.nil?
      score += lore["count"].to_f / highestScore.to_f
    end
  end
  score = score / words.length.to_f
  return score
end

def messageReceived(receivedData)
  if receivedData["metadata"]["message_type"] == "session_welcome"
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
      rep = subscribeToTwitchEventSub(receivedData["payload"]["session"]["id"], sub)
    end
  end
  if receivedData["metadata"]["message_type"] == "notification"
    case receivedData["payload"]["subscription"]["type"]
    when "channel.follow"
      message = [
        {
          "type": "text",
          "content": "#{receivedData["payload"]["event"]["user_name"]} has followed"
        }
      ]
      data = createMSGTwitch("Follow", "#ffd000", message, "notif")
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
      updateLastFollower()
    when "channel.chat.message"
      message = []
      receivedData["payload"]["event"]["message"]["fragments"].each do |frag|
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
      pfp_url = getTwitchUserPFP(receivedData["payload"]["event"]["chatter_user_login"])
      data = createMSGTwitch(receivedData["payload"]["event"]["chatter_user_name"], receivedData["payload"]["event"]["color"], message, "default", calculateLoreScore(receivedData).round(2))
      data["profile_image_url"] = pfp_url
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
      treatJoels(receivedData)
      treatForLore(receivedData)
      treat_twitch_commands(receivedData)
    when "channel.ad_break.begin"
      message = [
        {
          "type": "text",
          "content": "ads playing for #{receivedData["payload"]["event"]["duration_seconds"]} seconds"
        }
      ]
      data = createMSGTwitch("Ad Break", "#ffd000", message, "negatif")
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
    when "channel.subscribe"
      if receivedData["payload"]["event"]["is_gift"] == false
        message = [
          {
            "type": "text",
            "content": "#{receivedData["payload"]["event"]["user_name"]} has subscribed"
          }
        ]
        data = createMSGTwitch("Subscribe", "00ff00", message, "subscribe")
        msg = createMSG("twitch", "chat", data)
        sendToBus(msg)
      end
    when "channel.subscription.gift"
      if receivedData["payload"]["event"]["is_anonymous"] == false
        message = [{
          "type": "text",
          "content": "#{receivedData["payload"]["event"]["gifter_name"]} has gifted #{receivedData["payload"]["event"]["total"]} subs"
        }]
      else
        message = [{
          "type": "text",
          "content": "anonymous has gifted #{receivedData["payload"]["event"]["total"]} subs"
        }]
      end
      data = createMSGTwitch("Gift Sub", "#00ff00", message, "subscribe")
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
    when "channel.subscription.message"
      message = [{
        "type": "text",
        "content": "#{receivedData["payload"]["event"]["user_name"]} has resubscribed :\n #{receivedData["payload"]["event"]["message"]["text"]}"
      }]
      data = createMSGTwitch("Resub", "#00ff00", message, "subscribe")
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
    when "channel.cheer"
      if receivedData["payload"]["event"]["is_anonymous"] == false
        message = [{
          "type": "text",
          "content": "#{receivedData["payload"]["event"]["user_name"]} has cheered #{receivedData["payload"]["event"]["bits"]} bits"
        }]
      else
        message = [{
          "type": "text",
          "content": "anonymous has cheered #{receivedData["payload"]["event"]["bits"]} bits"
        }]
      end
      data = createMSGTwitch("Cheers", "#e100ff", message, "cheer")
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
    when "channel.raid"
      message = [{
        "type": "text",
        "content": "#{receivedData["payload"]["event"]["from_broadcaster_user_name"]} has raided with #{receivedData["payload"]["event"]["viewers"]} viewers !"
      }]
      data = createMSGTwitch("Raid", "#00ccff", message, "raid")
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
    end
  end
end

##### SPOTIFY #####

def getSpotifyToken()
  begin
    response = $TokenService.get("/token/spotify") do |req|
      req.headers["Authorization"] = $spotify_safety_string
    end
    rep = JSON.parse(response.body)
    $spotify_token = rep["token"]
  rescue
    puts "Token Service is down"
  end
end

def getSpotidyPlaybackState()
  begin
    response = $spotify_api_server.get("/v1/me/player") do |req|
      req.headers["Authorization"] = "Bearer #{$spotify_token}"
    end
  rescue
    return nil
  end
  if response.status != 204
    begin
      rep = JSON.parse(response.body)
    rescue
      return nil
    end
    if response.status == 200
      return rep
    else
      return nil
    end
  end
end

def updateSpotifyOverlay()
  playback = getSpotidyPlaybackState()
  if !playback.nil?
    begin
      music_name = playback["item"]["name"]
    rescue
      return
    end
    if music_name != $spotify_last_song_played
      $spotify_last_song_played = music_name
      begin
        music_artist = playback["item"]["artists"][0]["name"]
      rescue
        music_artist = "No artist"
      end
      begin
        music_image = playback["item"]["album"]["images"][0]["url"]
      rescue
        music_image = ""
      end
      msg = {
        "type": "song",
        "name": music_name,
        "artist": music_artist,
        "image": music_image,
        "progress_ms": playback["progress_ms"],
        "duration_ms": playback["item"]["duration_ms"]
      }
      msg = createMSG("spotify", "spotifyOverlay", msg)
      sendToBus(msg)
      $spotify_update_counter = 11
    else
      if $spotify_update_counter > 0
        $spotify_update_counter -= 1
        msg = {
          "type": "progress",
          "progress_ms": playback["progress_ms"],
          "duration_ms": playback["item"]["duration_ms"]
        }
        msg = createMSG("spotify", "spotifyOverlay", msg)
        sendToBus(msg)
      end
    end
  end
end

##### UTILS #####

def createMSG(from, to, data)
  return {
    "from": from,
    "to": to,
    "time": "#{Time.now().to_s.split(" ")[1]}",
    "payload": data
  }
end

def createMSGTwitch(name, name_color, message, type, loreScore = 0)
  return {
    "name": name,
    "name_color": name_color,
    "message": message,
    "type": type,
    "lore_score": loreScore
  }
end

def sendToBus(msg)
  if msg.is_a?(Hash)
    msg = msg.to_json
  end
  $bus.send(msg)
end

def sendQuery(queryName, body)
  begin
    response = $SQLService.post("/stream/#{queryName}") do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = body.to_json
    end
    if response.status != 200
      p response.status
      p response.body
    else
      return JSON.parse(response.body)
    end
  rescue
    return {}
  end
end

##### GODOT #####

def updateLastFollower()
  channel_id = getTwitchUserId("venorrak")
  response = $APItwitch.get("/helix/channels/followers?broadcaster_id=#{channel_id}") do |req|
      req.headers["Authorization"] = "Bearer #{$twitch_token}"
      req.headers["Client-Id"] = $twitch_bot_id
  end
  payload = JSON.parse(response.body)
  lastFollower = payload["data"][0]
  msg = {
    'command': 'last_follow_update',
    'params': {},
    'data': {
      "name": lastFollower["user_name"]
    }
  }
  msg = createMSG("twitch", "avatar", msg)
  sendToBus(msg)
end

def treatJoels(data)
  message = data["payload"]["event"]["message"]["text"]
  words = message.split(" ")
  nbJoelInMessage = 0
  words.each do |word|
    if $acceptedJoels.include?(word)
      nbJoelInMessage += 1
    end
  end
  if nbJoelInMessage > 0
    msg = {
      'command': 'Joel_Sent',
      'params': {
        "size": nbJoelInMessage
      },
      'data': {}
    }
    msg = createMSG("twitch", "avatar", msg)
    sendToBus(msg)
  end
end

##### POINTS #####

def updatePoints()
  response = $APItwitch.get("/helix/chat/chatters?broadcaster_id=#{$me_twitch_id}&moderator_id=#{$me_twitch_id}") do |req|
    req.headers["Authorization"] = "Bearer #{$twitch_token}"
    req.headers["Client-Id"] = $twitch_bot_id
  end
  begin
    rep = JSON.parse(response.body)
  rescue
    p "error getting chatters"
    return
  end
  chatters = rep["data"]
  chatters.each do |chatter|
    user_twitch_id = chatter["user_id"]
    user = sendQuery("getUser", [user_twitch_id])
    if user.nil?
      sendQuery("NewUser", [chatter["user_login"], user_twitch_id])
      new_user_id = sendQuery("GetUser", [user_twitch_id])["id"]
      sendQuery("NewPoints", [new_user_id])
    end
    if $points_users_last_scan.include?(chatter)
      user_id = sendQuery("GetUser", [user_twitch_id])["id"]
      sendQuery("AddPoints", [10, user_id])
    else
      $points_users_last_scan.push(chatter)
    end
    
  end
  $points_users_last_scan.each do |chatter|
    present = false
    chatters.each do |chatter2|
      if chatter["user_id"] == chatter2["user_id"]
        present = true
      end
    end
    if !present
      $points_users_last_scan.delete(chatter)
    end
  end

end

##### MAIN #####

getTwitchToken()
getSpotifyToken()

if $twitch_token.nil? || $spotify_token.nil?
  p "ERROR: tokens not retrieved"
  exit
end
$me_twitch_id = getTwitchUserId("venorrak")
if $me_twitch_id.nil?
  p "WARNING error getting twitch id for venorrak"
  exit
end
$online = true

Thread.start do
  loop do
    sleep(1)
    if $online
      now = AbsoluteTime.now
      if (now - $points_last_refresh) > 300
        updatePoints()
        $points_last_refresh = now
      end
      updateSpotifyOverlay()
    end
  end
end

#twitch
Thread.start do
  EM.run {
    ws = Faye::WebSocket::Client.new('wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30')

    ws.on :open do |event|
      #p [:open]
    end

    ws.on :message do |event|
      begin
        receivedData = JSON.parse(event.data)
      rescue
        p "non-json sent by twitch"
        return
      end
      messageReceived(receivedData)
    end

    ws.on :close do |event|
      p [:close, event.code, event.reason, "twitch"]
    end
  }
end

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
    if data["to"] == "BUS" && data["from"] == "BUS" && data["payload"] == "New client connected"
      updateLastFollower()
    end

    if data["to"] == "all" && data["from"] == "BUS"
      if data["payload"]["type"] == "token_refreshed"
        case data["payload"]["client"]
        when "twitch"
          getTwitchToken()
        when "spotify"
          getSpotifyToken()
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