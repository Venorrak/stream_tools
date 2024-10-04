class Spotify

  def initialize(twitch_token_password, myServer)
    $twitch_token_password = twitch_token_password
    $myServer = myServer
    getAccess()
    if $spotifyToken.nil?
      puts "couldn't get spotify token on initialization"
      exit
    end
  end

  $spotifyToken = nil

  $spotify_api_server = Faraday.new(url: "https://api.spotify.com") do |conn|
    conn.request :url_encoded
  end

  ##############################################################

  def getAccess()
    begin
      response = $myServer.get("/token/spotify") do |req|
        req.headers["Authorization"] = $twitch_token_password
      end
      rep = JSON.parse(response.body)
      $spotifyToken = rep["token"]
    rescue
      puts "stream server is down"
    end
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
end