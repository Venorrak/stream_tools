#token to access the API and IRC
@token = nil

#token to refresh the access token
@refreshToken = nil

FILEJSON = "chat/chat.json"

#connect to the server for authentication
$server = Faraday.new(url: "https://id.twitch.tv") do |conn|
    conn.request :url_encoded
end

#connect to the twitch api
$APItwitch = Faraday.new(url: "https://api.twitch.tv") do |conn|
    conn.request :url_encoded
end

def do_sleep(x = 1)
    sleep(x)
end

#function to get the access token for API and IRC
def getAccess()
    oauthToken = nil
    #https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#device-code-grant-flow
    response = $server.post("/oauth2/device") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = "client_id=#{@twitch_bot_id}&scopes=chat:read+chat:edit+user:bot+user:write:chat+channel:bot+user:manage:whispers+channel:moderate+moderator:read:followers+user:read:chat+channel:read:ads+channel:read:subscriptions+bits:read+moderator:manage:shoutouts+moderator:manage:announcements+channel:edit:commercial+moderator:manage:shoutouts+channel:manage:raids"
    end
    rep = JSON.parse(response.body)
    device_code = rep["device_code"]

    # wait for user to authorize the app
    puts "Please go to #{rep["verification_uri"]} and enter the code #{rep["user_code"]}"
    puts "Press enter when you have authorized the app"
    wait = gets.chomp

    #https://dev.twitch.tv/docs/authentication/getting-tokens-oauth/#authorization-code-grant-flow
    response = $server.post("/oauth2/token") do |req|
        req.body = "client_id=#{@twitch_bot_id}&scopes=channel:manage:broadcast,user:manage:whispers&device_code=#{device_code}&grant_type=urn:ietf:params:oauth:grant-type:device_code"
    end
    rep = JSON.parse(response.body)
    @token = rep["access_token"]
    @refreshToken = rep["refresh_token"]
end

#function to refresh the access token for API and IRC
def refreshAccess()

    #https://dev.twitch.tv/docs/authentication/refresh-tokens/#how-to-use-a-refresh-token
    response = $server.post("/oauth2/token") do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = "grant_type=refresh_token&refresh_token=#{@refreshToken}&client_id=#{@twitch_bot_id}&client_secret=#{@twitch_bot_secret}"
    end
    rep = JSON.parse(response.body)
    @token = rep["access_token"]
    @refreshToken = rep["refresh_token"]
end

#function to write the data to the JSON file
def writeToJSON(data)
    list = JSON.parse(File.read(File.join(__dir__, FILEJSON)))
    list.push(data)
    File.write(FILEJSON, list.to_json)
end

#function to subscribe to the eventsub
def subscribeToEventSub(channel_id, session_id, type)
    data = {
        "type" => type[:type],
        "version" => type[:version],
        "condition" => {
            "broadcaster_user_id" => channel_id,
            "to_broadcaster_user_id" => channel_id,
            "user_id" => channel_id,
            "moderator_user_id" => channel_id
        },
        "transport" => {
            "method" => "websocket",
            "session_id" => session_id
        }
    }.to_json
    response = $APItwitch.post("/helix/eventsub/subscriptions", data) do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end
    return JSON.parse(response.body)
end

def twitch_menu()
    system('clear')
    puts('1. start commercial')
    puts('2. create announcement')
    puts('3. shoutout')
    puts('4. create raid')
    puts('5. cancel raid')
    puts('6. get user data')
    puts('7. back')
    print('Enter your choice: ')
    choice = gets.chomp.to_i
    case choice
    when 1
        rep = start_commercial()
        pp rep
        gets
        twitch_menu()
    when 2
        rep = create_announcement()
        pp rep
        gets
        twitch_menu()
    when 3
        rep = shoutout()
        pp rep
        gets
        twitch_menu()
    when 4
        rep = create_raid()
        pp rep
        gets
        twitch_menu()
    when 5
        rep = cancel_raid()
        pp rep 
        gets
        twitch_menu()
    when 6
        print('Enter the username: ')
        name = gets.chomp
        rep = getTwitchUser(name)
        pp rep
        gets
        twitch_menu()
    when 7
        main_menu()
    else
        puts('Invalid choice')
        do_sleep()
        twitch_menu()
    end
end

#function to get the user data from the username with the API
def getTwitchUser(name)
    response = $APItwitch.get("/helix/users?login=#{name}") do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
    end
    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end
    return rep
end

#function to start a commercial with the API
def start_commercial()
    print('Enter the length of the commercial (secs, max 180): ')
    length = gets.chomp.to_i
    data = {
        "broadcaster_id": @me_id,
        "length": length
    }.to_json
    response = $APItwitch.post("/helix/channels/commercial", data) do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end
    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end

    case response.status
    when 200
        p "Commercial started"
    when 404
        p "User not found"
    when 429
        p "Too many requests"
    else
        p "something wrong"
    end

    return rep
end

#function to create an announcement with the API
def create_announcement()
    print('Enter the message: ')
    message = ""
    until message.length > 0 && message.length < 500
        message = gets.chomp
    end
    data = {
        "message": message
    }.to_json
    response = $APItwitch.post("/helix/chat/announcements?broadcaster_id=#{@me_id}&moderator_id=#{@me_id}", data) do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end
    rep = response.status

    case rep
    when 204
        rep = "Announcement created"
    else
        p response.status
        rep = "Can't create announcement"
    end

    return rep
end

#function to shoutout a user with the API
def shoutout()
    print('Enter the username: ')
    name = gets.chomp
    user = getTwitchUser(name)
    response = $APItwitch.post("/helix/chat/shoutouts?from_broadcaster_id=#{@me_id}&to_broadcaster_id=#{user["data"][0]["id"]}&moderator_id=#{@me_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
    end
    rep = response.status
    case rep
    when 204
        rep = "Shoutout created"
    when 403
        rep = "can't shoutout"
    when 429
        rep = "Too many requests"
    else
        rep = "something wrong"
    end

    return rep
end

#function to create a raid with the API
def create_raid()
    print('Enter the username: ')
    name = gets.chomp
    user = getTwitchUser(name)
    response = $APItwitch.post("/helix/raids?from_broadcaster_id=#{@me_id}&to_broadcaster_id=#{user["data"][0]["id"]}") do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
    end

    begin
        rep = JSON.parse(response.body)
    rescue
        rep = response.body
    end

    case response.status
    when 200
        p "Raid created"
    when 404
        p "User not found"
    when 429
        p "Too many requests"
    when 409
        p "Raid already in progress"
    else
        p "something wrong"
    end

    return rep
end

#function to cancel a raid with the API
def cancel_raid()
    response = $APItwitch.delete("/helix/raids?broadcaster_id=#{@me_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
    end
    rep = response.status

    case rep
    when 204
        rep = "Raid canceled"
    when 404
        rep = "No raid to cancel"
    when 429
        rep = "Too many requests"
    else
        rep = "something wrong"
    end

    return rep
end

#######################################################################################

getAccess()
@me_id = getTwitchUser("venorrak")["data"][0]["id"]

Thread.start do
    EM.run {
        ws = Faye::WebSocket::Client.new('wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30')

        ws.on :open do |event|
            p [:open]
        end

        ws.on :message do |event|
            data = [:message, event.data]
            data = JSON.parse(event.data)
            if data["metadata"]["message_type"] == "session_welcome"
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
                    rep = subscribeToEventSub(@me_id, data["payload"]["session"]["id"], sub)
                end
            end
            if data["metadata"]["message_type"] == "notification"
                case data["payload"]["subscription"]["type"]
                when "channel.follow"
                    msg = {
                        "name": "Follow",
                        "name_color": "yellow",
                        "message": "#{data["event"]["user_name"]} has followed",
                        "type": "notif"
                    }
                    writeToJSON(msg)

                when "channel.chat.message"
                    msg = {
                        "name": data["payload"]["event"]["chatter_user_name"],
                        "name_color": data["payload"]["event"]["color"],
                        "message": data["payload"]["event"]["message"]["text"],
                        "type": "default"
                    }
                    writeToJSON(msg)

                when "channel.ad_break.begin"
                    msg = {
                        "name": "Ad Break",
                        "name_color": "red",
                        "message": "ads playing for #{data["event"]["duration_seconds"]} seconds",
                        "type": "negatif"
                    }
                    writeToJSON(msg)

                when "channel.subscribe"
                    if data["event"]["is_gift"] == false
                        msg = {
                            "name": "Subscribe",
                            "name_color": "green",
                            "message": "#{data["event"]["user_name"]} has subscribed",
                            "type": "subscibe"
                        }
                        writeToJSON(msg)
                    end
                
                when "channel.subscription.gift"
                    if data["event"]["is_anonymous"] == false
                        msg = {
                            "name": "Gift Sub",
                            "name_color": "green",
                            "message": "anonymous has gifted #{data["event"]["total"]} subs",
                            "type": "subscibe"
                        }
                    else
                        msg = {
                            "name": "Gift Sub",
                            "name_color": "green",
                            "message": "#{data["event"]["gifter_name"]} has gifted #{data["event"]["total"]} subs",
                            "type": "subscibe"
                        }
                    end
                    writeToJSON(msg)

                when "channel.subscription.message"
                    msg = {
                        "name": "Resub",
                        "name_color": "green",
                        "message": "#{data["event"]["user_name"]} has resubscribed \n#{data["event"]["message"]["text"]}",
                        "type": "subscibe"
                    }
                    writeToJSON(msg)

                when "channel.cheer"
                    if data["event"]["is_anonymous"] == false
                        msg = {
                            "name": "Cheers",
                            "name_color": "purple",
                            "message": "#{data["event"]["user_name"]} has cheered #{data["event"]["bits"]} bits",
                            "type": "cheer"
                        }
                    else
                        msg = {
                            "name": "Cheers",
                            "name_color": "purple",
                            "message": "anonymous has cheered #{data["event"]["bits"]} bits",
                            "type": "cheer"
                        }
                    end
                    writeToJSON(msg)

                when "channel.raid"
                    msg = {
                        "name": "Raid",
                        "name_color": "pink",
                        "message": "#{data["event"]["from_broadcaster_user_name"]} has raided with #{data["event"]["viewers"]} viewers",
                        "type": "raid"
                    }
                    writeToJSON(msg)
                end
            end
        end

        ws.on :close do |event|
            p [:close, event.code, event.reason]
        end
    }
end

