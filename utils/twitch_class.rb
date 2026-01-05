class Twitch
  def initialize(twitch_bot_id, twitch_token_password, myServer)

    $twitch_bot_id = twitch_bot_id
    $twitch_token_password = twitch_token_password

    $APItwitch = Faraday.new(url: "https://api.twitch.tv") do |conn|
      conn.request :url_encoded
    end

    $emotes_conn = Faraday.new(url: "https://static-cdn.jtvnw.net") do |conn|
      conn.request :url_encoded
    end

    $myServer = myServer

    $token = nil
    $me_id = nil
    getAccess()
    if $token.nil?
        puts "couldn't get the token on initialization"
        exit
    end
    $me_id = getTwitchUser("venorrak")["data"][0]["id"]
  end

  def do_sleep(x = 1)
    sleep(x)
  end

  #get token from the server
  def getAccess()
    begin
        response = $myServer.get("/token/twitch") do |req|
        req.headers["Authorization"] = $twitch_token_password
        end
        rep = JSON.parse(response.body)
        $token = rep["token"]
    rescue
        puts "stream server is down"
    end
  end

  #print nicely the status and the data
  def printResults(status, rep = nil)
    puts status
    if !rep.nil?
      ap rep
    end
    gets
    twitch_menu()
  end

  #########################################################################
  #                           TWITCH FUNCTIONS                            #
  #########################################################################

  #function to subscribe to the eventsub
  def subscribeToEventSub(session_id, type)
    data = {
        "type" => type[:type],
        "version" => type[:version],
        "condition" => {
            "broadcaster_user_id" => $me_id,
            "to_broadcaster_user_id" => $me_id,
            "user_id" => $me_id,
            "moderator_user_id" => $me_id
        },
        "transport" => {
            "method" => "websocket",
            "session_id" => session_id
        }
    }.to_json
    response = $APItwitch.post("/helix/eventsub/subscriptions", data) do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end
    return JSON.parse(response.body)
  end

  #function to get the user data from the username with the API
  def getTwitchUser(name)
    response = $APItwitch.get("/helix/users?login=#{name}") do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
    end
    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end
    return rep
  end

  #function to start a commercial with the API
  def start_commercial(length)
    data = {
        "broadcaster_id": $me_id,
        "length": length
    }.to_json
    response = $APItwitch.post("/helix/channels/commercial", data) do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end
    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end

    return response.status, rep
  end

  #function to create an announcement with the API
  def create_announcement(message)
    data = {
        "message": message
    }.to_json
    response = $APItwitch.post("/helix/chat/announcements?broadcaster_id=#{$me_id}&moderator_id=#{$me_id}", data) do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end

    return response.status
  end

  #function to shoutout a user with the API
  def shoutout(name)
    user_exists = false
    begin
        user_id = getTwitchUser(name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
    end
    if user_exists == true
        response = $APItwitch.post("/helix/chat/shoutouts?from_broadcaster_id=#{$me_id}&to_broadcaster_id=#{user_id}&moderator_id=#{$me_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end
        rep = response.status
    end

    return rep
  end

  #function to create a raid with the API
  def create_raid(name)
    user_exists = false
    responseStatus = nil
    begin
        user_id = getTwitchUser(name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
        responseStatus = 404
    end
    if user_exists == true
        response = $APItwitch.post("/helix/raids?from_broadcaster_id=#{$me_id}&to_broadcaster_id=#{user_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end

        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end
        responseStatus = response.status
    end

    return responseStatus, rep
  end

  #function to cancel a raid with the API
  def cancel_raid()
    response = $APItwitch.delete("/helix/raids?broadcaster_id=#{$me_id}") do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
    end

    return response.status
  end

  #function to snooze the ad with the API for 5 minutes
  def snooze_ad()
    response = $APItwitch.post("/helix/channels/ads/schedule/snooze?broadcaster_id=#{$me_id}") do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
    end

    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end

    return response.status, rep
  end

  #function to get the channel info with the API
  def get_channel_info(name)
    channel_exists = false
    responseStatus = nil
    begin
        channel_id = getTwitchUser(name)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
        responseStatus = 404
    end
    if channel_exists == true
        response = $APItwitch.get("/helix/channels?broadcaster_id=#{channel_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end

        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end
        responseStatus = response.status
    end

    return responseStatus, rep
  end

  #function to get the channel stream info with the API
  def change_stream_title(title)
    data = {
        "title": title
    }.to_json
    response = $APItwitch.patch("/helix/channels?broadcaster_id=#{$me_id}") do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
        req.headers["Content-Type"] = "application/json"
        req.body = data
    end

    return response.status
  end

  #function to get the channel followers with the API can specify a user
  def get_channel_follow(channel_name, user_name)
    channel_exists = false
    user_exists = false
    responseStatus = nil
    begin
        channel_id = getTwitchUser(channel_name)["data"][0]["id"]
        channel_exists = true
        if !user_name.nil?
            user_id = getTwitchUser(user_name)["data"][0]["id"]
            user_exists = true
        end
    rescue
        rep = "channel doesn't exist"
        responseStatus = 404
    end
    if channel_exists == true
        if user_name.nil?
            response = $APItwitch.get("/helix/channels/followers?broadcaster_id=#{channel_id}") do |req|
                req.headers["Authorization"] = "Bearer #{$token}"
                req.headers["Client-Id"] = $twitch_bot_id
            end
        else
            response = $APItwitch.get("/helix/channels/followers?broadcaster_id=#{channel_id}&user_id=#{user_id}") do |req|
                req.headers["Authorization"] = "Bearer #{$token}"
                req.headers["Client-Id"] = $twitch_bot_id
            end
        end

        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end
        responseStatus = response.status
    end

    return responseStatus, rep
  end

  #function to get viewers of my channel with the API
  def get_viewers(channelName)
    channelId = getTwitchUser(channelName)["data"][0]["id"]
    response = $APItwitch.get("/helix/chat/chatters?broadcaster_id=#{channelId}&moderator_id=#{$me_id}") do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
    end

    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end

    return response.status, rep
  end

  #function to get emotes of channel
  def get_channel_emotes(channel_name)
    channel_exists = false
    responseStatus = nil
    begin
        channel_id = getTwitchUser(channel_name)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
        responseStatus = 404
    end
    if channel_exists == true
        response = $APItwitch.get("/helix/chat/emotes?broadcaster_id=#{channel_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end

        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end
        responseStatus = response.status
    end

    return responseStatus, rep
  end

  #function to get the general emoticons
  def get_global_emotes()
    response = $APItwitch.get("/helix/chat/emotes/global") do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
    end

    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end

    return response.status, rep
  end

  #function to get the badges of the channel
  def get_channel_badge(channel_name)
    channel_exists = false
    responseStatus = nil
    begin
        channel_id = getTwitchUser(channel_name)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
        responseStatus = 404
    end
    if channel_exists == true
        response = $APItwitch.get("/helix/chat/badges?broadcaster_id=#{channel_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end

        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end
        responseStatus = response.status
    end

    return responseStatus, rep
  end

  #function to get the global badges
  def get_global_badge()
    response = $APItwitch.get("/helix/chat/badges/global") do |req|
        req.headers["Authorization"] = "Bearer #{$token}"
        req.headers["Client-Id"] = $twitch_bot_id
    end

    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end

    return response.status, rep
  end

  #function to ban a user
  def ban_user(user_name, duration, reason)
    user_exists = false
    responseStatus = nil
    user = getTwitchUser(user_name)
    duration = duration * 60
    pre_data = {}
    begin
        pre_data["user_id"] = user["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
        responseStatus = 404
    end
    if user_exists == true
        if duration != 0
            pre_data["duration"] = duration
        end
        if reason != "" || reason != nil
            pre_data["reason"] = reason
        end
        data = {
            "data": pre_data
        }.to_json
        response = $APItwitch.post("/helix/moderation/bans?broadcaster_id=#{$me_id}&moderator_id=#{$me_id}", data) do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end
        
        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end
        responseStatus = response.status
    end

    return responseStatus, rep

  end

  #function to unban a user
  def unban_user(user_name)
    user_exists = false
    responseStatus = nil
    begin
        user_id = getTwitchUser(user_name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
        responseStatus = 404
    end
    if user_exists == true
        response = $APItwitch.delete("/helix/moderation/bans?broadcaster_id=#{$me_id}&moderator_id=#{@me_id}&user_id#{user_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end
        
        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end
        responseStatus = response.status
    end

    return responseStatus, rep
  end

  #function to give vip to a user
  def add_vip(user_name)
    user_exists = false
    begin
        user_id = getTwitchUser(user_name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
    end
    if user_exists == true
        response = $APItwitch.post("/helix/moderation/vips?broadcaster_id=#{$me_id}&user_id=#{user_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end
        rep = response.status
    end

    return rep
  end

  #function to remove vip from a user
  def remove_vip(user_name)
    user_exists = false
    begin
        user_id = getTwitchUser(user_name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
    end
    if user_exists == true
        response = $APItwitch.delete("/helix/moderation/vips?broadcaster_id=#{$me_id}&user_id=#{user_id}") do |req|
            req.headers["Authorization"] = "Bearer #{$token}"
            req.headers["Client-Id"] = $twitch_bot_id
        end
        rep = response.status
    end

    return rep
  end

  #function to send a message in the specified channel
  def send_message(channel, message)
    channel_exists = false
    responseStatus = nil
    begin
        channel_id = getTwitchUser(channel)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
        responseStatus = 404
    end
    if channel_exists == true
      request_body = {
          "broadcaster_id": channel_id,
          "sender_id": $me_id,
          "message": message
      }.to_json
      sleep(1)
      response = $APItwitch.post("/helix/chat/messages", request_body) do |req|
          req.headers["Authorization"] = "Bearer #{$token}"
          req.headers["Client-Id"] = $twitch_bot_id
          req.headers["Content-Type"] = "application/json"
      end

      begin
          rep = JSON.parse(response.body)
      rescue
          rep = response.body
      end
      responseStatus = response.status
    end
    return responseStatus, rep
  end

end