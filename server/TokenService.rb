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

$twitch_auth_server = Faraday.new(url: "https://id.twitch.tv") do |conn|
  conn.request :url_encoded
end

set :port, 5002
set :bind, '0.0.0.0'
disable :protection # Disable CSRF protection for simplicity
set :host_authorization, { permitted_hosts: [] }

get '/token/twitch' do
  return [
    200,
    {"Content-Type" => "application/json"},
    {"token" => $twitch_token}.to_json
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

getTwitchAccess()

Thread.start do
  loop do
    now = Time.now.to_i
    sleep(60)

    if (now - $twitch_last_refresh) > 3600
      refreshTwitchAccess()
      $twitch_last_refresh = now
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