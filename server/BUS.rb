require "bundler/inline"
require "json"
require 'faye/websocket'
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require "base64"
require "digest"
require 'timeout'
require 'websocket-eventmachine-server'
require "openssl"

gemfile do
  source "https://rubygems.org"
  gem "faraday"
  gem 'sinatra-contrib'
  gem 'rackup'
  gem 'webrick'
  require 'sinatra'
end

require "faraday"
require_relative "secret.rb"

set :port, 9898
set :bind, '0.0.0.0'

$WsClients = []
$online = false

$spotify_token = nil
$spotify_refresh_token = nil
$spotify_last_refresh = AbsoluteTime.now
$spotify_last_song_played = nil
$spotify_update_counter = 0

$twitch_token = nil
$twitch_refresh_token = nil
$twitch_last_refresh = AbsoluteTime.now
$me_twitch_id = nil

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
  response = $server.post("/oauth2/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = "grant_type=refresh_token&refresh_token=#{$twitch_refresh_token}&client_id=#{$twitch_bot_id}&client_secret=#{$twitch_bot_secret}"
  end
  rep = JSON.parse(response.body)
  $twitch_token = rep["access_token"]
  $twitch_refresh_token = rep["refresh_token"]
  msg = createMSG("BUS", "cli", {
    "type": "token_refreshed",
    "client": "twitch"
  })
  sendToAllClients(msg)
end

def refreshSpotifyAccess()
  body = {
    "grant_type": "refresh_token",
    "refresh_token": $spotify_refresh_token
  }
  body_encoded = URI.encode_www_form(body)
  response = $spotify_auth_server.post("/api/token", body_encoded) do |req|
    req.headers["Content-Type"] = "application/x-www-form-urlencoded"
    req.headers["Authorization"] = "Basic " + Base64.strict_encode64("#{$spotify_client_id}:#{$spotify_client_secret}")
  end
  if response.status != 200
    p response.status
    p response.body
  else
    rep = JSON.parse(response.body)
    $spotify_token = rep['access_token']
    msg = createMSG("BUS", "cli", {
      "type": "token_refreshed",
      "client": "spotify"
    })
    sendToAllClients(msg)
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
  response = $APItwitch.get("/helix/users?login=#{username}") do |req|
    req.headers["Authorization"] = "Bearer #{$twitch_token}"
    req.headers["Client-Id"] = $twitch_bot_id
  end
  rep = JSON.parse(response.body)
  return rep["data"][0]["id"]
end

def getTwitchUserPFP(username)
  response = $APItwitch.get("/helix/users?login=#{username}") do |req|
    req.headers["Authorization"] = "Bearer #{$twitch_token}"
    req.headers["Client-Id"] = $twitch_bot_id
  end
  rep = JSON.parse(response.body)
  begin
    return rep["data"][0]["profile_image_url"]
  rescue
    ap rep
    return "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fdivedigital.id%2Fwp-content%2Fuploads%2F2022%2F07%2F2-Blank-PFP-Icon-Instagram.jpg&f=1&nofb=1&ipt=a0b42ddbcd36b663a8af0c817aeb97394e66d999f6f6613150ed5cf9466123c8&ipo=images"
  end
end

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

def getSpotidyPlaybackState()
  response = $spotify_api_server.get("/v1/me/player") do |req|
    req.headers["Authorization"] = "Bearer #{$spotify_token}"
  end
  if response.status != 204
    rep = JSON.parse(response.body)
  end
  if response.status == 200
    return rep
  else
    return nil
  end
end

def updateSpotifyOverlay()
  playback = getSpotidyPlaybackState()
  if !playback.nil?
    if playback["item"]["name"] != $spotify_last_song_played
      $spotify_last_song_played = playback["item"]["name"]
      msg = {
        "type": "song",
        "name": playback["item"]["name"],
        "artist": playback["item"]["artists"][0]["name"],
        "image": playback["item"]["album"]["images"][0]["url"],
        "progress_ms": playback["progress_ms"],
        "duration_ms": playback["item"]["duration_ms"]
      }
      msg = createMSG("spotify", "spotifyOverlay", msg)
      sendToAllClients(msg)
      $spotify_update_counter = 6
    else
      if $spotify_update_counter > 0
        $spotify_update_counter -= 1
        msg = {
          "type": "progress",
          "progress_ms": playback["progress_ms"],
          "duration_ms": playback["item"]["duration_ms"]
        }
        msg = createMSG("spotify", "spotifyOverlay", msg)
        sendToAllClients(msg)
      end
    end
  end
end

def sendToAllClients(msg)
  if msg.is_a?(Hash)
    msg = msg.to_json
  end
  printBus(msg)
  $WsClients.each do |client|
    client.send(msg)
  end
end

def printBus(msg)
  msg = JSON.parse(msg)
  puts "#{msg["time"] || Time.now().to_s.split(" ")[1]} - #{msg["from"]} to #{msg["to"]} : #{msg["payload"]}"
end

def send_twitch_message(channel, message)
  begin
    channel_id = getTwitchUserId(channel)
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
  rescue
    p "error sending message"
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
            msg = {
              'command': 'change_color',
              'params': {},
              'data': color
            }
            createMSG("twitch", "avatar", msg)
            sendToAllClients(msg)
          end
      when "!rainbow"
        msg = {
          'command': 'starting_on_off',
          'params': {},
          'data': {}
        }
        createMSG("twitch", "avatar", msg)
        sendToAllClients(msg)
      when "!dum"
        msg = {
          'command': 'dum_on_off',
          'params': {},
          'data': {}
        }
        createMSG("twitch", "avatar", msg)
        sendToAllClients(msg)
      when "!discord"
        send_twitch_message("venorrak", "Join the discord server: https://discord.gg/ydJ7NCc8XM")
      when "!commands"
        send_twitch_message("venorrak", "Commands: !color #ffffff, !rainbow, !dum, !song, !commands")
      when "!c"
        send_twitch_message("venorrak", "Commands: !color #ffffff, !rainbow, !dum, !song, !commands")
      when "!song"
        msg = {
          "type": "show"
        }
        msg = createMSG("twitch", "spotifyOverlay", msg)
        sendToAllClients(msg)
        $spotify_update_counter = 6
      end
  end
end

getTwitchAccess()
$me_twitch_id = getTwitchUserId("venorrak")
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
        $spotify_last_refresh = now
      end
      updateSpotifyOverlay()
    end
  end
end

Thread.start do
  EM.run {
    ws = Faye::WebSocket::Client.new('wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30')

    ws.on :open do |event|
      #p [:open]
    end

    ws.on :message do |event|
      receivedData = JSON.parse(event.data)
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
          sendToAllClients(msg)
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
          sendToAllClients(msg)
          treat_twitch_commands(receivedData)
        when "channel.ad_break.begin"
          message = [
            {
              "type": "text",
              "content": "ads playing for #{data["payload"]["event"]["duration_seconds"]} seconds"
            }
          ]
          data = createMSGTwitch("Ad Break", "#ffd000", message, "negatif")
          msg = createMSG("twitch", "chat", data)
          sendToAllClients(msg)
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
            sendToAllClients(msg)
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
              "content": "anonymous has gifted #{data["payload"]["event"]["total"]} subs"
            }]
          end
          data = createMSGTwitch("Gift Sub", "#00ff00", message, "subscribe")
          msg = createMSG("twitch", "chat", data)
          sendToAllClients(msg)
        when "channel.subscription.message"
          message = [{
            "type": "text",
            "content": "#{data["payload"]["event"]["user_name"]} has resubscribed :\n #{data["payload"]["event"]["message"]["text"]}"
          }]
          data = createMSGTwitch("Resub", "#00ff00", message, "subscribe")
          msg = createMSG("twitch", "chat", data)
          sendToAllClients(msg)
        when "channel.cheer"
          if receivedData["payload"]["event"]["is_anonymous"] == false
            message = [{
              "type": "text",
              "content": "#{data["payload"]["event"]["user_name"]} has cheered #{data["payload"]["event"]["bits"]} bits"
            }]
          else
            message = [{
              "type": "text",
              "content": "anonymous has cheered #{data["payload"]["event"]["bits"]} bits"
            }]
          end
          data = createMSGTwitch("Cheers", "#e100ff", message, "cheer")
          msg = createMSG("twitch", "chat", data)
          sendToAllClients(msg)
        when "channel.raid"
          message = [{
            "type": "text",
            "content": "#{data["payload"]["event"]["from_broadcaster_user_name"]} has raided with #{data["payload"]["event"]["viewers"]} viewers !"
          }]
          data = createMSGTwitch("Raid", "#00ccff", message, "raid")
          msg = createMSG("twitch", "chat", data)
          sendToAllClients(msg)
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
    WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 5963) do |ws|
      ws.onopen do
        $WsClients.push(ws)
      end

      ws.onmessage do |msg|
        sendToAllClients(msg)
      end

      ws.onclose do
        $WsClients.delete(ws)
        ws.close
      end

      ws.onerror do |e|
        ap e
      end
    end
  end
end