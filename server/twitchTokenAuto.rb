require 'bundler/inline'
require 'awesome_print'
require "openssl"
require "json"
require 'absolute_time'

gemfile do
  source 'https://rubygems.org'
  gem 'faraday'
  gem 'sinatra-contrib'
  gem 'rackup'
  gem 'webrick'
end
require 'faraday'
require 'sinatra'

set :port, 6543
set :bind, '0.0.0.0'

$token = nil
$refresh_token = nil
$lastRefresh = Time.now

$server = Faraday.new(url: "https://id.twitch.tv") do |conn|
  conn.request :url_encoded
end

get '/' do
  if request.env['HTTP_AUTHORIZATION'] == "|)0ntGe7|)0xeD"
    return [
      200,
      {"Content-Type" => "application/json"},
      {"token" => $token}.to_json
    ]
  end
end

def getAccess()
  oauthToken = nil
  #https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#device-code-grant-flow
  response = $server.post("/oauth2/device") do |req|
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
  response = $server.post("/oauth2/token") do |req|
      req.body = "client_id=#{$twitch_bot_id}&scopes=channel:manage:broadcast,user:manage:whispers&device_code=#{device_code}&grant_type=urn:ietf:params:oauth:grant-type:device_code"
  end
  rep = JSON.parse(response.body)
  $token = rep["access_token"]
  $refreshToken = rep["refresh_token"]
end

def refreshAccess()

  #https://dev.twitch.tv/docs/authentication/refresh-tokens/#how-to-use-a-refresh-token
  response = $server.post("/oauth2/token") do |req|
      req.headers["Content-Type"] = "application/x-www-form-urlencoded"
      req.body = "grant_type=refresh_token&refresh_token=#{$refreshToken}&client_id=#{$twitch_bot_id}&client_secret=#{$twitch_bot_secret}"
  end
  rep = JSON.parse(response.body)
  $token = rep["access_token"]
  $refreshToken = rep["refresh_token"]
end

getAccess()

Thread.start do
  loop do
      sleep(60)
      now = Absolutetime.now
      if (now - $lastRefresh) > 7200
          refreshAccess()
          $lastRefresh = now
      end
  end
end