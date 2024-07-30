require "bundler/inline"
require "json"
require "openssl"
require "awesome_print"
require "securerandom"
require 'websocket-eventmachine-server'

gemfile do
  source "https://rubygems.org"
  gem "faraday"
end

require "faraday"
require_relative "secret.rb"

$token = nil
$clients = []


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
      'get playback state',
      "resume track",
      "pause track",
      "skip track",
      "previous track",
      "set volume",
      "get queue",
      "add track to queue"
  ]
  system('clear')
  choices.each_with_index do |choice, index|
      puts("#{index + 1}. #{choice}")
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  case choice
  when 1
    ap getPlaybackState()
    gets
    spotify_menu()
  when 2
    resumeTrack()
    gets
    spotify_menu()
  when 3
    pauseTrack()
    gets
    spotify_menu()
  when 4
    skipTrack()
    gets
    spotify_menu()
  when 5
    previousTrack()
    gets
    spotify_menu()
  when 6
    print('Enter volume: ')
    volume = gets.chomp.to_i
    setVolume(volume)
    gets
    spotify_menu()
  when 7 
    getQueue()
    gets
    spotify_menu()
  when 8
    print('Enter url: ')
    url = gets.chomp
    uri = getUriFromUrl(url)
    if uri != nil
      if isThisARealSong(uri)
        addTrackToQueue(uri)
      else
        puts('Invalid song')
      end
    else
      puts('Invalid url')
    end
    gets
    spotify_menu()
  else
      puts('Invalid choice')
      sleep(1)
      spotify_menu()
  end
end

def getPlaybackState()
  response = $spotify_api_server.get("/v1/me/player") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  rep = JSON.parse(response.body)
  return rep
end

def resumeTrack()
  position_ms = getPlaybackState()["progress_ms"]
  response = $spotify_api_server.put("/v1/me/player/play", {"position_ms": position_ms}.to_json) do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  p response.status
end

def pauseTrack()
  response = $spotify_api_server.put("/v1/me/player/pause") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  p response.status
end

def skipTrack()
  response = $spotify_api_server.post("/v1/me/player/next") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  p response.status
end

def previousTrack()
  response = $spotify_api_server.post("/v1/me/player/previous") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  p response.status
end

def setVolume(volume)
  response = $spotify_api_server.put("/v1/me/player/volume?volume_percent=#{volume}") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  p response.status
end

def getQueue()
  response = $spotify_api_server.get("/v1/me/player/queue") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  rep = JSON.parse(response.body)
  return rep
end

def addTrackToQueue(uri)
  uriString = "spotify:track:#{uri}"
  response = $spotify_api_server.post("/v1/me/player/queue?uri=#{uriString}") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  p response.status
end

def getUriFromUrl(url)
  if url.start_with?("https://open.spotify.com/track/")
    url = url.delete_prefix("https://open.spotify.com/track/")
    uri = url.split("?")[0]
    return uri
  else
    return nil
  end
end

def isThisARealSong(uri)
  response = $spotify_api_server.get("/v1/tracks/#{uri}") do |req|
    req.headers["Authorization"] = "Bearer #{$token}"
  end
  if response.status == 200
    return true
  else
    return false
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

def sendToAll(message)
  $clients.each do |client|
    client.send(message)
  end
end

##############################################################

getAccess()

Thread.start do
  loop do
    sleep(1)
    playback = getPlaybackState()
    $current_song_id = playback["item"]["id"]
    if $current_song_id != $last_song_id
      #song changed
      data = {
        "name" => playback["item"]["name"],
        "artist" => playback["item"]["artists"][0]["name"],
        "image" => playback["item"]["album"]["images"][0]["url"],
        "progress_ms" => playback["progress_ms"],
        "duration_ms" => playback["item"]["duration_ms"]
      }
      ap data
      sendToAll(data.to_json)
    end
    $last_song_id = $current_song_id
  end
end

#spotify_menu()


Thread.start do
  loop do
      sleep(3000)
      $token = getAccess()
  end
end

EM.run do
  WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 5962) do |ws|
    ws.onopen do
      $clients << ws
      p 'Client connected'
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