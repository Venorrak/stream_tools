require "bundler/inline"
require "json"
require "openssl"
require "awesome_print"
require "securerandom"
require 'absolute_time'

gemfile do
  source "https://rubygems.org"
  gem "faraday"
  gem 'sinatra-contrib'
  gem 'rackup'
  gem 'webrick'
  require 'sinatra'
end

require 'sinatra'
require 'faraday'
require_relative 'secret.rb'

set :port, 5557
set :bind, '0.0.0.0'

$token = nil
$refresh_token = nil
$lastRefresh = AbsoluteTime.now

$spotify_auth_server = Faraday.new(url: "https://accounts.spotify.com") do |conn|
  conn.request :url_encoded
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

get '/request' do
  if request.env['HTTP_AUTHORIZATION'] == $spotify_safety_string
    return [
      200,
      {"Content-Type" => "application/json"},
      {"token" => $token}.to_json
    ]
  else
    return [
      401,
      {"Content-Type" => "application/json"},
      {"error" => "good try buddy"}.to_json
    ]
  end
end

def authorize_spotify()
  response = $spotify_auth_server.get("/authorize") do |req|
    req.params["client_id"] = $spotify_client_id
    req.params["response_type"] = "code"
    req.params["redirect_uri"] = "http://192.168.0.16:5557/callback"
    req.params["scope"] = "app-remote-control streaming user-read-playback-state user-modify-playback-state"  
    req.params["state"] = SecureRandom.alphanumeric(16)
  end
  p response.headers["location"]
end

def get_spotify_token(code)
  body = {
    grant_type: "authorization_code",
    code: code,
    redirect_uri: "http://192.168.0.16:5557/callback"
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
    $token = rep['access_token']
    $refresh_token = rep['refresh_token']
    p "expires in: #{rep['expires_in']}"
  end
end

def refreshAccess()
  body = {
    "grant_type": "refresh_token",
    "refresh_token": $refresh_token
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
    $token = rep['access_token']
  end
end

authorize_spotify()

Thread.start do
  loop do
      sleep(60)
      now = AbsoluteTime.now
      if (now - $lastRefresh) > 2500
          refreshAccess()
          $lastRefresh = now
      end
  end
end