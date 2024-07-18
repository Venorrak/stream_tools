require "bundler/inline"
require "json"
require "openssl"
require "awesome_print"
require "securerandom"

gemfile do
  source "https://rubygems.org"
  gem "faraday"
end

require "faraday"
require_relative "secret.rb"

$token = nil

$spotify_api_server = Faraday.new(url: "https://api.spotify.com") do |conn|
  conn.request :url_encoded
end

$myServer = Faraday.new(url: "http://192.168.0.16:5557") do |conn|
  conn.request :url_encoded
end

##############################################################

def getAccess
  response = $myServer.get("/request") do |req|
    req.headers["Authorization"] = $twitch_token_password
  end
  rep = JSON.parse(response.body)
  $token = rep["token"]
end

def spotify_menu()
  choices = [
      'get playback state'
  ]
  #system('clear')
  choices.each_with_index do |choice, index|
      puts("#{index + 1}. #{choice}")
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  case choice
  when 1
      Thread.start do
          loop do
              getPlaybackState()
              sleep(1)
          end
      end
      spotify_menu()
  else
      puts('Invalid choice')
      do_sleep()
      twitch_menu()
  end
end

def getPlaybackState()
  response = $spotify_api_server.get("/v1/me/player") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  begin
    rep = JSON.parse(response.body)
    current_time = rep["progress_ms"]
    total_time = rep["item"]["duration_ms"]
    playbackDisplay(current_time, total_time)
  end
end

def playbackDisplay(current_time, total_time)
  system('clear')
  num_segments = 100
  print("[")
  total_segments = (current_time * num_segments) / total_time
  total_segments.times do
    print("=")
  end
  (num_segments - total_segments).times do
    print(" ")
  end
  print("]")
end

##############################################################

getAccess()

spotify_menu()

Thread.start do
  loop do
      sleep(3000)
      $token = getAccess()
  end
end