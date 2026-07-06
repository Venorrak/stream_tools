class TwitchApi
    @client_id = nil
    @client_secret = nil
    @tokenService = nil
    @myTwitchId = nil
    @token = nil

    @APItwitch = nil

    @thread = nil

    def initialize(client_id, client_secret, tokenService)
        @client_id = client_id
        @client_secret = client_secret
        @tokenService = tokenService
        @APItwitch = Faraday.new(url: "https://api.twitch.tv") do |conn|
            conn.request :url_encoded
        end
    end

    def getToken() 
        begin
            response = @tokenService.get("/token/twitch")
            rep = JSON.parse(response.body)
            puts(rep)
            @token = rep["token"]
        rescue => e
            puts "Token Service is down: #{e}"
        end
    end

    def subscribeToTwitchEventSub(session_id, type)
        data = {
            "type" => type[:type],
            "version" => type[:version],
            "condition" => {
                "broadcaster_user_id" => @myTwitchId,
                "to_broadcaster_user_id" => @myTwitchId,
                "user_id" => @myTwitchId,
                "moderator_user_id" => @myTwitchId
            },
            "transport" => {
                "method" => "websocket",
                "session_id" => session_id
            }
        }.to_json
        response = @APItwitch.post("/helix/eventsub/subscriptions", data) do |req|
            req.headers["Authorization"] = "Bearer #{@token}"
            req.headers["Client-Id"] = @client_id
            req.headers["Content-Type"] = "application/json"
        end
        return JSON.parse(response.body)
    end

    def getTwitchUserId(username)
        begin
            response = @APItwitch.get("/helix/users?login=#{username}") do |req|
                req.headers["Authorization"] = "Bearer #{@token}"
                req.headers["Client-Id"] = @client_id
            end
            rep = JSON.parse(response.body)
        rescue
            return nil
        end
        return rep["data"][0]["id"]
    end

    def getTwitchUserPFP(username)
        begin
            response = @APItwitch.get("/helix/users?login=#{username}") do |req|
                req.headers["Authorization"] = "Bearer #{@token}"
                req.headers["Client-Id"] = @client_id
            end
            rep = JSON.parse(response.body)
        rescue
            return ""
        end
        begin
            return rep["data"][0]["profile_image_url"]
        rescue
            ap rep
            return "https://external-content.duckduckgo.com/iu/?u=https%3A%2F%2Fdivedigital.id%2Fwp-content%2Fuploads%2F2022%2F07%2F2-Blank-PFP-Icon-Instagram.jpg&f=1&nofb=1&ipt=a0b42ddbcd36b663a8af0c817aeb97394e66d999f6f6613150ed5cf9466123c8&ipo=images"
        end
    end

    def send_twitch_message(channel, message)
        begin
            channel_id = getTwitchUserId(channel)
            if channel == "venorrak"
            message = "[📺] #{message}"
            end
            request_body = {
                "broadcaster_id": channel_id,
                "sender_id": @myTwitchId,
                "message": message
            }.to_json
            response = @APItwitch.post("/helix/chat/messages", request_body) do |req|
                req.headers["Authorization"] = "Bearer #{@token}"
                req.headers["Client-Id"] = @client_id
                req.headers["Content-Type"] = "application/json"
            end
            p response.status
        rescue
            p "error sending message"
        end
    end

    def send_twitch_shoutout(channel_id)
        begin
            response = @APItwitch.post("/helix/chat/shoutouts?from_broadcaster_id=#{@myTwitchId}&to_broadcast_id=#{channel_id}&moderator_id=#{@myTwitchId}") do |req|
            req.headers["Authorization"] = "Bearer #{@token}"
            req.headers["Client-Id"] = @client_id
        end
        p response.status
        rescue
            p "error sending shoutout"
        end
    end

    def treat_twitch_commands(data)
        first_frag = data["payload"]["event"]["message"]["fragments"][0]
        if first_frag["type"] == "text"
            words = first_frag["text"].strip.split(" ")
            case words[0].downcase
            when "!song"
                playbacks = $MusicApi.getPlaybackState()
                if playbacks.nil?
                    puts "no playback data"
                end
                playbacks = playbacks["entry"]
                if playbacks.nil? || playbacks.empty?
                    send_twitch_message("venorrak", "No song is currently playing.")
                    return
                end
                playback = playbacks[0]
                send_twitch_message("venorrak", "Currently playing: #{playback["title"]} by #{playback["artist"]}.")
            end
        end
    end

    def messageReceived(receivedData)
        if receivedData["metadata"]["message_type"] == "session_welcome"
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
                rep = subscribeToTwitchEventSub(receivedData["payload"]["session"]["id"], sub)
            end
        end
        if receivedData["metadata"]["message_type"] == "session_reconnect"
            @thread.kill
            startThread()
        end
        if receivedData["metadata"]["message_type"] == "notification"
            case receivedData["payload"]["subscription"]["type"]
            when "channel.follow"
                msg = createMSG(["twitch", "follow"], { 
                    "name": receivedData["payload"]["event"]["user_name"],
                })
                sendToBus(msg)
            when "channel.chat.message"
                message = []
                receivedData["payload"]["event"]["message"]["fragments"].each do |frag|
                    if frag["type"] == "text"
                    message.push({
                        "type": "text",
                        "content": frag["text"]
                    })
                    elsif frag["type"] == "emote"
                    message.push({
                        "type": "emote",
                        "id": frag["emote"]["id"]
                    })
                    else
                    message.push({
                        "type": "text",
                        "content": frag["text"]
                    })
                    end
                end
                pfp_url = getTwitchUserPFP(receivedData["payload"]["event"]["chatter_user_login"])
                msg = createMSG(["twitch", "message"], {
                    "name": receivedData["payload"]["event"]["chatter_user_name"],
                    "id": receivedData["payload"]["event"]["chatter_user_id"],
                    "name_color": receivedData["payload"]["event"]["color"],
                    "message": message,
                    "pfp": pfp_url,
                    "badges": receivedData["payload"]["event"]["badges"],
                    "raw_message": receivedData["payload"]["event"]["message"]["text"],
                })
                sendToBus(msg)
                treat_twitch_commands(receivedData)
            when "channel.ad_break.begin"
                msg = createMSG(["twitch", "ads", "begin"], {
                    "duration": receivedData["payload"]["event"]["duration_seconds"],
                })
                sendToBus(msg)
            when "channel.subscribe"
                if receivedData["payload"]["event"]["is_gift"] == false
                    msg = createMSG(["twitch", "sub"], {
                        "name": receivedData["payload"]["event"]["user_name"],
                    })
                    sendToBus(msg)
                end
            when "channel.subscription.gift"
                msg = createMSG(["twitch", "sub", "gift"], {
                    "name": receivedData["payload"]["event"]["gifter_name"],
                    "count": receivedData["payload"]["event"]["total"],
                    "anonymous": receivedData["payload"]["event"]["is_anonymous"],
                })
                sendToBus(msg)
            when "channel.subscription.message"
                msg = createMSG(["twitch", "sub", "resub"], {
                    "name": receivedData["payload"]["event"]["user_name"],
                    "message": receivedData["payload"]["event"]["message"]["text"],
                })
                sendToBus(msg)
            when "channel.cheer"
                msg = createMSG(["twitch", "cheer"], {
                    "name": receivedData["payload"]["event"]["user_name"],
                    "count": receivedData["payload"]["event"]["bits"],
                    "anonymous": receivedData["payload"]["event"]["is_anonymous"],
                })
                sendToBus(msg)
            when "channel.raid"
                msg = createMSG(["twitch", "raid"], {
                    "name": receivedData["payload"]["event"]["from_broadcaster_user_name"],
                    "count": receivedData["payload"]["event"]["viewers"],
                })
                send_twitch_shoutout(receivedData["payload"]["event"]["from_broadcaster_user_id"])
                sendToBus(msg)
            end
        end
    end

    def getCurrentViewers()
        response = @APItwitch.get("/helix/chat/chatters?broadcaster_id=#{@myTwitchId}&moderator_id=#{@myTwitchId}") do |req|
            req.headers["Authorization"] = "Bearer #{@token}"
            req.headers["Client-Id"] = @client_id
        end
        begin
            rep = JSON.parse(response.body)
        rescue
            p "error getting chatters"
            return
        end
        return rep["data"]
    end

    def createMSG(subject, payload)
        return {
            "subject": subject.join("."),
            "payload": payload
        }
    end

    def sendToBus(msg)
        begin
            if msg.is_a?(Hash)
            msg = msg.to_json
            end
            $bus.send(msg)
        rescue => e
            p e
            return
        end
    end

    def startThread()
        puts "Starting Twitch EventSub WebSocket Thread"
        getToken()
        if @token.nil?
            p "ERROR: could not get twitch token"
            exit
        end
        @myTwitchId = getTwitchUserId("venorrak")
        if @myTwitchId.nil?
            p "ERROR: could not get twitch user id"
            exit
        end
        @thread = Thread.start do
            EM.run {
                ws = Faye::WebSocket::Client.new('wss://eventsub.wss.twitch.tv/ws?keepalive_timeout_seconds=30')

                ws.on :open do |event|
                    #p [:open]
                end

                ws.on :message do |event|
                    begin
                        receivedData = JSON.parse(event.data)
                    rescue
                        p "non-json sent by twitch"
                        return
                    end
                    messageReceived(receivedData)
                end

                ws.on :close do |event|
                    p [:close, event.code, event.reason, "twitch"]
                    p Time.now
                end
            }
        end
    end
    
end