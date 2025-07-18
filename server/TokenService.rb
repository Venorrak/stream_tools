require "json"
require "bundler/inline"
require 'faye/websocket'
require 'eventmachine'
require "openssl"

gemfile do
  source "https://rubygems.org"
  gem "faraday"
  gem 'sinatra-contrib'
  gem 'rackup'
  gem 'webrick'
  require "sinatra"
end

require "faraday"
require_relative "secret.rb"

$twitch_token = nil
$twitch_refresh_token = nil
$twitch_last_refresh = Time.now.to_i
$spotify_token = nil
$spotify_refresh_token = nil
$spotify_last_refresh = Time.now.to_i

$spotify_auth_server = Faraday.new(url: "https://accounts.spotify.com") do |conn|
  conn.request :url_encoded
end

$twitch_auth_server = Faraday.new(url: "https://id.twitch.tv") do |conn|
  conn.request :url_encoded
end

$ntfy_server = Faraday.new(url: 'https://ntfy.venorrak.dev') do |conn|
  conn.request :url_encoded
end

set :port, 5002
set :bind, '0.0.0.0'
disable :protection # Disable CSRF protection for simplicity
set :host_authorization, { permitted_hosts: [] }

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
    msg = createMSG(["token", "twitch"], {
      "status": "refreshed",
    })
    sendToBus(msg)
  else
    p "error refreshing twitch token"
    p rep
  end
end

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
      msg = createMSG(["token", "spotify"], {
        "status": "refreshed",
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
    req.params["redirect_uri"] = "http://192.168.0.16:5002/callback" #TODO: change 
    req.params["scope"] = "app-remote-control streaming user-read-playback-state user-modify-playback-state"  
    req.params["state"] = SecureRandom.alphanumeric(16)
  end
  p response.headers["location"]
end

def get_spotify_token(code)
  body = {
    grant_type: "authorization_code",
    code: code,
    redirect_uri: "http://192.168.0.16:5002/callback" #TODO: change
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
    p "expires in: #{rep['expires_in']}"
  end
end

def createMSG(subject, payload)
  return {
    "subject": subject.join("."),
    "payload": payload
  }
end

def sendToBus(msg)
  if msg.is_a?(Hash)
    msg = msg.to_json
  end
  $bus.send(msg)
end

def sendNotif(message, title)
  rep = $ntfy_server.post("/TokenService") do |req|
      req.headers["host"] = "ntfy.venorrak.dev"
      req.headers["Priority"] = "5"
      req.headers["Title"] = title
      req.body = message
  end
end

getTwitchAccess()
authorize_spotify()

Thread.start do
  loop do
    now = Time.now.to_i
    sleep(60)

    if (now - $twitch_last_refresh) > 3600
      refreshTwitchAccess()
      $twitch_last_refresh = now
    end

    if (now - $spotify_last_refresh) > 3600
      refreshSpotifyAccess()
      $spotify_last_refresh = now
    end
  end
end

Thread.start do
  EM.run do
    bus = Faye::WebSocket::Client.new("ws://bus:5000")

    bus.on :open do |event|
      $bus = bus
      p [:open, "BUS"]
    end

    bus.on :error do |event|
      p [:error, event.message, "BUS"]
    end

    bus.on :close do |event|
      p [:close, event.code, event.reason, "BUS"]
      sendNotif("connection with BUS lost", "Token Service closed")
    end
  end
end