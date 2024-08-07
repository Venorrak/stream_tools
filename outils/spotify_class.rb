class Spotify

  def initialize(twitch_token_password)
    $twitch_token_password = twitch_token_password
    getAccess()
  end

  $spotifyToken = nil

  $spotify_api_server = Faraday.new(url: "https://api.spotify.com") do |conn|
    conn.request :url_encoded
  end

  $myServer2 = Faraday.new(url: "http://192.168.0.16:9898") do |conn|
    conn.request :url_encoded
  end

  ##############################################################

  def getAccess()
    response = $myServer2.get("/token/spotify") do |req|
      req.headers["Authorization"] = $twitch_token_password
    end
    rep = JSON.parse(response.body)
    $spotifyToken = rep["token"]
  end

  def getPlaybackState()
    response = $spotify_api_server.get("/v1/me/player") do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
    end
    rep = JSON.parse(response.body)
    return rep
  end

  def resumeTrack()
    position_ms = getPlaybackState()["progress_ms"]
    response = $spotify_api_server.put("/v1/me/player/play", {"position_ms": position_ms}.to_json) do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
    end
    p response.status
  end

  def pauseTrack()
    response = $spotify_api_server.put("/v1/me/player/pause") do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
    end
    p response.status
  end

  def skipTrack()
    response = $spotify_api_server.post("/v1/me/player/next") do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
    end
    p response.status
  end

  def previousTrack()
    response = $spotify_api_server.post("/v1/me/player/previous") do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
    end
    p response.status
  end

  def setVolume(volume)
    response = $spotify_api_server.put("/v1/me/player/volume?volume_percent=#{volume}") do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
    end
    p response.status
  end

  def getQueue()
    response = $spotify_api_server.get("/v1/me/player/queue") do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
    end
    rep = JSON.parse(response.body)
    return rep
  end

  def addTrackToQueue(uri)
    uriString = "spotify:track:#{uri}"
    response = $spotify_api_server.post("/v1/me/player/queue?uri=#{uriString}") do |req|
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
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
      req.headers["Authorization"] = "Bearer #{$spotifyToken}"
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

  def sendToAll(message, clients)
    clients.each do |client|
      client.send(message)
    end
  end

  def setToken(token)
    $spotifyToken = token
  end

end