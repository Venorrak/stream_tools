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

def send_twitch_shoutout(channel_id)
  begin
    response = $APItwitch.post("/helix/chat/shoutouts?from_broadcaster_id=#{$me_twitch_id}&to_broadcast_id=#{channel_id}&moderator_id=#{$me_twitch_id}") do |req|
      req.headers["Authorization"] = "Bearer #{$twitch_token}"
      req.headers["Client-Id"] = $twitch_bot_id
  end
  p response.status
  rescue
    p "error sending shoutout"
  end
end

def treat_twitch_commands(data)
  first_frag = data["payload"]["event"]["message"]["fragments"][0]
  if first_frag["type"] == "text"
    words = first_frag["text"].strip.split(" ")
    case words[0].downcase
    when "!song"
      playback = getSpotidyPlaybackState()
      music_link = playback["item"]["external_urls"]["spotify"]
      playlist_link = playback["context"]["external_urls"]["spotify"]
      send_twitch_message("venorrak", "Currently playing: #{music_link}. Listen to the playlist here: #{playlist_link}")
    end
  end
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
      msg = createMSG(["twitch", "follow"], {
        "name": receivedData["payload"]["event"]["user_name"],
      })
      sendToBus(msg)
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
      msg = createMSG(["twitch", "message"], {
        "name": receivedData["payload"]["event"]["chatter_user_name"],
        "name_color": receivedData["payload"]["event"]["color"],
        "message": message,
        "pfp": pfp_url,
        "badges": receivedData["payload"]["event"]["badges"],
        "raw_message": receivedData["payload"]["event"]["message"]["text"],
      })
      sendToBus(msg)
      treat_twitch_commands(receivedData)
    when "channel.ad_break.begin"
      msg = createMSG(["twitch", "ads", "begin"], {
        "duration": receivedData["payload"]["event"]["duration_seconds"],
      })
      sendToBus(msg)
    when "channel.subscribe"
      if receivedData["payload"]["event"]["is_gift"] == false
        msg = createMSG(["twitch", "sub"], {
          "name": receivedData["payload"]["event"]["user_name"],
        })
        sendToBus(msg)
      end
    when "channel.subscription.gift"
      msg = createMSG(["twitch", "sub", "gift"], {
        "name": receivedData["payload"]["event"]["gifter_name"],
        "count": receivedData["payload"]["event"]["total"],
        "anonymous": receivedData["payload"]["event"]["is_anonymous"],
      })
      sendToBus(msg)
    when "channel.subscription.message"
      msg = createMSG(["twitch", "sub", "resub"], {
        "name": receivedData["payload"]["event"]["user_name"],
        "message": receivedData["payload"]["event"]["message"]["text"],
      })
      sendToBus(msg)
    when "channel.cheer"
      msg = createMSG(["twitch", "cheer"], {
        "name": receivedData["payload"]["event"]["user_name"],
        "count": receivedData["payload"]["event"]["bits"],
        "anonymous": receivedData["payload"]["event"]["is_anonymous"],
      })
      sendToBus(msg)
    when "channel.raid"
      msg = createMSG(["twitch", "raid"], {
        "name": receivedData["payload"]["event"]["from_broadcaster_user_name"],
        "count": receivedData["payload"]["event"]["viewers"],
      })
      send_twitch_shoutout(receivedData["payload"]["event"]["from_broadcaster_user_id"])
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
      msg = createMSG(["spotify", "song", "start"], {
        "title": music_name,
        "artist": music_artist,
        "image": music_image,
        "duration_ms": playback["item"]["duration_ms"],
      })
      sendToBus(msg)
    end
  end
end

def changePlaylist(id)
  begin
    body = {
      "context_uri": "spotify:playlist:#{id}"
    }.to_json
    response = $spotify_api_server.put("/v1/me/player/play", body) do |req|
      req.headers["Authorization"] = "Bearer #{$spotify_token}"
    end
  rescue
    return nil
  end
end

##### UTILS #####

def createMSG(subject, payload)
  return {
    "subject": subject.join("."),
    "payload": payload
  }
end

def sendToBus(msg)
  begin
    if msg.is_a?(Hash)
      msg = msg.to_json
    end
    $bus.send(msg)
  rescue => e
    p e
    return
  end
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
    user = sendQuery("GetUser", [user_twitch_id])
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
  bus = Faye::WebSocket::Client.new('ws://192.168.0.16:5000')

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
    keywords = data["subject"].split(".")
    case keywords[0]
      when "command"
        case keywords[1]
        when "sendMessage"
          send_twitch_message("venorrak", data["payload"]["content"])
        when "changePlaylist"
          changePlaylist(data["payload"]["content"])
        end
      when "token"
        case keywords[1]
        when "twitch"
          if data["payload"]["status"] == "refreshed"
            getTwitchToken()
          end
        when "spotify"
          if data["payload"]["status"] == "refreshed"
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