require "bundler/inline"
require "json"
require 'faye/websocket'
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require "openssl"

gemfile do
  source "https://rubygems.org"
  gem "faraday"
  gem 'sinatra-contrib'
  gem 'rackup'
  gem 'webrick'
  gem "mysql2"
  require 'sinatra'
end

require "faraday"
require "mysql2"
require_relative "secret.rb"

set :port, 9898
set :bind, '0.0.0.0'

$online = false
$bus = nil

$spotify_token = nil
$spotify_refresh_token = nil
$spotify_last_refresh = AbsoluteTime.now
$spotify_last_song_played = nil
$spotify_update_counter = 0

$twitch_token = nil
$twitch_refresh_token = nil
$twitch_last_refresh = AbsoluteTime.now
$me_twitch_id = nil

$points_last_refresh = AbsoluteTime.now
$points_users_last_scan = []

$acceptedJoels = ["GoldenJoel" , "Joel2" , "Joeler" , "Joel" , "jol" , "JoelCheck" , "JoelbutmywindowsXPiscrashing" , "JOELLINES", "Joeling", "Joeling", "LetHimJoel", "JoelPride", "WhoLetHimJoel", "Joelest", "EvilJoel", "JUSSY", "JoelJams", "JoelTrain", "BarrelJoel", "JoelWide1", "JoelWide2", "Joeling2"]

$spotify_auth_server = Faraday.new(url: "https://accounts.spotify.com") do |conn|
  conn.request :url_encoded
end

$twitch_auth_server = Faraday.new(url: "https://id.twitch.tv") do |conn|
  conn.request :url_encoded
end

$APItwitch = Faraday.new(url: "https://api.twitch.tv") do |conn|
  conn.request :url_encoded
end

$spotify_api_server = Faraday.new(url: "https://api.spotify.com") do |conn|
  conn.request :url_encoded
end

$myWebPage = Faraday.new(url: "https://server.venorrak.dev") do |conn|
  conn.request :url_encoded
end

$sql = Mysql2::Client.new(:host => "localhost", :username => "bus", :password => "1234")
$sql.query("USE stream;")

$sqlNewUser = $sql.prepare("INSERT INTO users (name, twitch_id) VALUES (?, ?);")
$sqlNewPoints = $sql.prepare("INSERT INTO points (user_id, points) VALUES (?, 0);")
$sqlGetUser = $sql.prepare("SELECT id, name FROM users WHERE twitch_id = ?;")
$sqlAddPoints = $sql.prepare("UPDATE points SET points = points + ? WHERE user_id = ?;")
$sqlRemovePoints = $sql.prepare("UPDATE points SET points = points - ? WHERE user_id = ?;")
$sqlGetPoints = $sql.prepare("SELECT points FROM points WHERE user_id = ?;")

##### ROUTES #####

get '/token/spotify' do
  if request.env['HTTP_AUTHORIZATION'] == $spotify_safety_string
    return [
      200,
      {"Content-Type" => "application/json"},
      {"token" => $spotify_token}.to_json
    ]
  else
    return [
      401,
      {"Content-Type" => "text/html"},
      ["<p>Unauthorized</p>"]
    ]
  end
end

get '/token/twitch' do
  if request.env['HTTP_AUTHORIZATION'] == $twitch_safety_string
    return [
      200,
      {"Content-Type" => "application/json"},
      {"token" => $twitch_token}.to_json
    ]
  else
    return [
      401,
      {"Content-Type" => "text/html"},
      ["<p>Unauthorized</p>"]
    ]
  end
end

get '/callback' do
  if !params['error'].nil?
    p params['error']
    break
  end
  code = params['code']
  get_spotify_token(code)
  return [
    200,
    {"Content-Type" => "text/html"},
    ["<p>Spotify token received</p>"]
  ]
end

##### TWITCH #####

def getTwitchAccess()
  oauthToken = nil
  #https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#device-code-grant-flow
  response = $twitch_auth_server.post("/oauth2/device") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = "client_id=#{$twitch_bot_id}&scopes=chat:read+chat:edit+user:bot+user:write:chat+channel:bot+user:manage:whispers+channel:moderate+moderator:read:followers+user:read:chat+channel:read:ads+channel:read:subscriptions+bits:read+moderator:manage:shoutouts+moderator:manage:announcements+channel:edit:commercial+moderator:manage:shoutouts+channel:manage:raids+moderator:read:chatters+channel:manage:vips+channel:manage:ads+channel:manage:broadcast"
  end
  rep = JSON.parse(response.body)
  device_code = rep["device_code"]

  # wait for user to authorize the app
  puts "Please go to #{rep["verification_uri"]} and enter the code #{rep["user_code"]}"
  puts "Press enter when you have authorized the app"
  wait = gets.chomp

  #https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#authorization-code-grant-flow
  response = $twitch_auth_server.post("/oauth2/token") do |req|
      req.body = "client_id=#{$twitch_bot_id}&scopes=channel:manage:broadcast,user:manage:whispers&device_code=#{device_code}&grant_type=urn:ietf:params:oauth:grant-type:device_code"
  end
  rep = JSON.parse(response.body)
  $twitch_token = rep["access_token"]
  $twitch_refresh_token = rep["refresh_token"]
end

def refreshTwitchAccess()
  #https://dev.twitch.tv/docs/authentication/refresh-tokens/#how-to-use-a-refresh-token
  response = $twitch_auth_server.post("/oauth2/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = "grant_type=refresh_token&refresh_token=#{$twitch_refresh_token}&client_id=#{$twitch_bot_id}&client_secret=#{$twitch_bot_secret}"
  end
  begin
    rep = JSON.parse(response.body)
  rescue
    p response.body
    return
  end
  if !rep["access_token"].nil? && !rep["refresh_token"].nil?
    $twitch_token = rep["access_token"]
    $twitch_refresh_token = rep["refresh_token"]
    msg = createMSG("BUS", "cli", {
      "type": "token_refreshed",
      "client": "twitch"
    })
    sendToBus(msg)
  else
    p "error refreshing twitch token"
    p rep
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
      words = first_frag["text"].split(" ")
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
      data = createMSGTwitch(receivedData["payload"]["event"]["chatter_user_name"], receivedData["payload"]["event"]["color"], message, "default")
      data["profile_image_url"] = pfp_url
      msg = createMSG("twitch", "chat", data)
      sendToBus(msg)
      treatJoels(receivedData)
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

def refreshSpotifyAccess()
  body = {
    "grant_type": "refresh_token",
    "refresh_token": $spotify_refresh_token
  }
  body_encoded = URI.encode_www_form(body)
  begin
    response = $spotify_auth_server.post("/api/token", body_encoded) do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{$spotify_client_id}:#{$spotify_client_secret}")
    end
  rescue
    p "error accessing spotify server"
    return
  end
  if response.status != 200
    p response.status
    p response.body
  else
    rep = JSON.parse(response.body)
    if !rep['access_token'].nil?
      $spotify_token = rep['access_token']
      msg = createMSG("BUS", "cli", {
        "type": "token_refreshed",
        "client": "spotify"
      })
      sendToBus(msg)
    else
      p "error refreshing spotify token"
      p rep
    end
  end
end

def authorize_spotify()
  response = $spotify_auth_server.get("/authorize") do |req|
    req.params["client_id"] = $spotify_client_id
    req.params["response_type"] = "code"
    req.params["redirect_uri"] = "http://192.168.0.16:9898/callback" #TODO: change 
    req.params["scope"] = "app-remote-control streaming user-read-playback-state user-modify-playback-state"  
    req.params["state"] = SecureRandom.alphanumeric(16)
  end
  p response.headers["location"]
end

def get_spotify_token(code)
  body = {
    grant_type: "authorization_code",
    code: code,
    redirect_uri: "http://192.168.0.16:9898/callback" #TODO: change
  }
  body_encoded = URI.encode_www_form(body)
  response = $spotify_auth_server.post("/api/token", body_encoded) do |req|
    req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{$spotify_client_id}:#{$spotify_client_secret}")
    req.headers["Content-Type"] = "application/x-www-form-urlencoded"
  end
  if response.status != 200
    p response.status
    p "error getting token"
  else
    rep = JSON.parse(response.body)
    $spotify_token = rep['access_token']
    $spotify_refresh_token = rep['refresh_token']
    $online = true
    p "expires in: #{rep['expires_in']}"
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

def createMSGTwitch(name, name_color, message, type)
  return {
    "name": name,
    "name_color": name_color,
    "message": message,
    "type": type
  }
end

def sendToBus(msg)
  if msg.is_a?(Hash)
    msg = msg.to_json
  end
  $bus.send(msg)
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
    user = $sqlGetUser.execute(user_twitch_id).first
    if user.nil?
      $sqlNewUser.execute(chatter["user_login"], user_twitch_id)
      new_user_id = $sqlGetUser.execute(user_twitch_id).first["id"]
      $sqlNewPoints.execute(new_user_id)
    end
    if $points_users_last_scan.include?(chatter)
      user_id = $sqlGetUser.execute(user_twitch_id).first["id"]
      $sqlAddPoints.execute(10, user_id)
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

getTwitchAccess()
$me_twitch_id = getTwitchUserId("venorrak")
if $me_twitch_id.nil?
  p "WARNING error getting twitch id for venorrak"
  exit
end
authorize_spotify()

Thread.start do
  loop do
    sleep(1)
    if $online
      now = AbsoluteTime.now
      if (now - $twitch_last_refresh) > 7200
        refreshTwitchAccess()
        $twitch_last_refresh = now
      end
      if (now - $spotify_last_refresh) > 2500
        refreshSpotifyAccess()
        $sql.query('SELECT 1;')
        $spotify_last_refresh = now
      end
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
      if data["to"] == "BUS" && data["from"] == "BUS" && data["payload"] == "New client connected"
        updateLastFollower()
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