#token to access the API and IRC
@token = nil

FILEJSON = "chat/chat.json"

#connect to the server for authentication
$server = Faraday.new(url: "https://id.twitch.tv") do |conn|
    conn.request :url_encoded
end

#connect to the twitch api
$APItwitch = Faraday.new(url: "https://api.twitch.tv") do |conn|
    conn.request :url_encoded
end

$emotes_conn = Faraday.new(url: "https://static-cdn.jtvnw.net") do |conn|
    conn.request :url_encoded
end

$myServer = Faraday.new(url: "http://192.168.0.16:6543") do |conn|
    conn.request :url_encoded
end

def do_sleep(x = 1)
    sleep(x)
end

#function to get the access token for API and IRC
def getAccess()
    response = $myServer.get("/") do |req|
        req.headers["Authorization"] = $twitch_token_password
    end
    rep = JSON.parse(response.body)
    @token = rep["token"]
end

#function to write the data to the JSON file
def writeToJSON(data)
    list = JSON.parse(File.read(File.join(__dir__, FILEJSON)))
    list.push(data)
    File.write(FILEJSON, list.to_json)
end

def quick_end_case(rep = nil)
    ap rep
    gets
    twitch_menu()
end

#menu
def twitch_menu()
    choices = [
        "start commercial",
        "create announcement",
        "shoutout",
        "create raid",
        "cancel raid",
        "get user data",
        "snooze ad",
        "get channel info",
        "change stream title",
        "get channel followers",
        "get viewers",
        "get channel emotes",
        "get global emotes",
        "get channel badges",
        "get global badges",
        "ban user",
        "unban user",
        "add vip",
        "remove vip",
        "send message",
        "back to main menu"
    ]
    system('clear')
    choices.each_with_index do |choice, index|
        puts("#{index + 1}. #{choice}")
    end
    print('Enter your choice: ')
    choice = gets.chomp.to_i
    case choice
    when 1
        print('Enter the length of the commercial (secs, max 180): ')
        length = gets.chomp.to_i
        if length == 0
            rep = start_commercial()
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 2
        print('Enter the message (exit to abort): ')
        message = ""
        until message.length > 0 && message.length < 500 || message == "exit"
            message = gets.chomp
        end
        if message != "exit"
            rep = create_announcement(message)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 3
        print('Enter the username: ')
        name = gets.chomp
        if name != ""
            rep = shoutout(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 4
        print('Enter the username: ')
        name = gets.chomp
        if name != ""
            rep = create_raid(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 5
        rep = cancel_raid()
        quick_end_case(rep)
    when 6
        print('Enter the username: ')
        name = gets.chomp
        if name != ""
            rep = getTwitchUser(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 7
        rep = snooze_ad()
        quick_end_case(rep)
    when 8
        print('Enter the channel name: ')
        name = gets.chomp
        if name != ""
            rep = get_channel_info(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 9
        print('Enter the title: ')
        title = gets.chomp
        if title != ""
            rep = change_stream_title(title)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 10
        print('Enter the channel name: ')
        name = gets.chomp
        if name != ""
            print('Enter the user name (optional = ""): ')
            user = gets.chomp
            if user == ""
                user = nil
            end
            rep = get_channel_follow(name, user)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 11
        rep = get_viewers()
        quick_end_case(rep)
    when 12
        print('Enter the channel name: ')
        name = gets.chomp
        if name != ""
            rep = get_channel_emotes(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 13
        rep = get_global_emotes()
        quick_end_case(rep)
    when 14
        print('Enter the channel name: ')
        name = gets.chomp
        if name != ""
            rep = get_channel_badge(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 15
        rep = get_global_badge()
        quick_end_case(rep)
    when 16
        print('Enter the username: ')
        name = gets.chomp
        if name != ""
            print('Enter the duration (mins, 0 = permanent): ')
            duration = gets.chomp.to_i
            print('Enter the reason (optional = ""): ')
            reason = gets.chomp
            if reason == ""
                reason = nil
            end
            rep = ban_user(name, duration, reason)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 17
        print('Enter the username: ')
        name = gets.chomp
        if name != ""
            rep = unban_user(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 18
        print('Enter the username: ')
        name = gets.chomp
        if name != ""
            rep = add_vip(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 19
        print('Enter the username: ')
        name = gets.chomp
        if name != ""
            rep = remove_vip(name)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 20
        print('Enter message: ')
        message = gets.chomp
        print('Enter channel: ')
        channel = gets.chomp
        if message != "" && channel != ""
            rep = send_message(channel, message)
            quick_end_case(rep)
        else
            quick_end_case()
        end
    when 21
        main_menu()
    else
        puts('Invalid choice')
        do_sleep()
        twitch_menu()
    end
end


########################################################################################

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
def start_commercial(length)
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
def create_announcement(message)
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
def shoutout(name)
    user_exists = false
    begin
        user_id = getTwitchUser(name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
    end
    if user_exists == true
        response = $APItwitch.post("/helix/chat/shoutouts?from_broadcaster_id=#{@me_id}&to_broadcaster_id=#{user_id}&moderator_id=#{@me_id}") do |req|
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
    end

    return rep
end

#function to create a raid with the API
def create_raid(name)
    user_exists = false
    begin
        user_id = getTwitchUser(name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
    end
    if user_exists == true
        response = $APItwitch.post("/helix/raids?from_broadcaster_id=#{@me_id}&to_broadcaster_id=#{user_id}") do |req|
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

#function to snooze the ad with the API for 5 minutes
def snooze_ad()
    response = $APItwitch.post("/helix/channels/ads/schedule/snooze?broadcaster_id=#{@me_id}") do |req|
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
        p "Ad snoozed"
    when 404
        p "bad request"
    when 429
        p "Too many requests"
    else
        p "something wrong"
    end

    return rep
end

#function to get the channel info with the API
def get_channel_info(name)
    channel_exists = false
    begin
        channel_id = getTwitchUser(name)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
    end
    if channel_exists == true
        response = $APItwitch.get("/helix/channels?broadcaster_id=#{channel_id}") do |req|
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
            p "Channel info"
        when 400
            p "bad request"
        when 401
            p "Unauthorized"
        when 429
            p "Too many requests"
        else
            p "something wrong"
        end
    end

    return rep
end

#function to get the channel stream info with the API
def change_stream_title(title)
    data = {
        "title": title
    }.to_json
    response = $APItwitch.patch("/helix/channels?broadcaster_id=#{@me_id}") do |req|
        req.headers["Authorization"] = "Bearer #{@token}"
        req.headers["Client-Id"] = @twitch_bot_id
        req.headers["Content-Type"] = "application/json"
        req.body = data
    end

    case response.status
    when 204
        rep = "Title changed"
    when 400
        rep = "bad request"
    when 401
        rep = "Unauthorized"
    when 403
        rep = "Forbidden"
    when 429
        rep = "Too many requests"
    else
        rep = "something wrong"
    end

    return rep
end

#function to get the channel followers with the API can specify a user
def get_channel_follow(channel_name, user_name)
    channel_exists = false
    user_exists = false
    begin
        channel_id = getTwitchUser(channel_name)["data"][0]["id"]
        channel_exists = true
        if !user_name.nil?
            user_id = getTwitchUser(user_name)["data"][0]["id"]
            user_exists = true
        end
    rescue
        rep = "channel doesn't exist"
    end
    if channel_exists == true
        if user_name.nil?
            response = $APItwitch.get("/helix/channels/followers?broadcaster_id=#{channel_id}") do |req|
                req.headers["Authorization"] = "Bearer #{@token}"
                req.headers["Client-Id"] = @twitch_bot_id
            end
        else
            response = $APItwitch.get("/helix/channels/followers?broadcaster_id=#{channel_id}&user_id=#{user_id}") do |req|
                req.headers["Authorization"] = "Bearer #{@token}"
                req.headers["Client-Id"] = @twitch_bot_id
            end
        end

        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end

        case response.status
        when 200
            p "Followers"
        when 400
            p "bad request"
        when 401
            p "Unauthorized"
        when 429
            p "Too many requests"
        else
            p "something wrong"
        end
    end

    return rep
end

#function to get viewers of my channel with the API
def get_viewers()
    response = $APItwitch.get("/helix/chat/chatters?broadcaster_id=#{@me_id}&moderator_id=#{@me_id}") do |req|
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
        p "Viewers"
    when 400
        p "bad request"
    when 401
        p "Unauthorized"
    when 403
        p "Forbidden"
    when 429
        p "Too many requests"
    else
        p "something wrong"
    end

    return rep
end

#function to get emotes of channel
def get_channel_emotes(channel_name)
    channel_exists = false
    begin
        channel_id = getTwitchUser(channel_name)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
    end
    if channel_exists == true
        response = $APItwitch.get("/helix/chat/emotes?broadcaster_id=#{channel_id}") do |req|
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
            p "Emotes"
        when 400
            p "bad request"
        when 401
            p "Unauthorized"
        when 429
            p "Too many requests"
        else
            p "something wrong"
        end
    end

    return rep
end

#function to get the general emoticons
def get_global_emotes()
    response = $APItwitch.get("/helix/chat/emotes/global") do |req|
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
        p "Global emotes"
    when 400
        p "bad request"
    when 401
        p "Unauthorized"
    when 429
        p "Too many requests"
    else
        p "something wrong"
    end

    return rep
end

#function to get the badges of the channel
def get_channel_badge(channel_name)
    channel_exists = false
    begin
        channel_id = getTwitchUser(channel_name)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
    end
    if channel_exists == true
        response = $APItwitch.get("/helix/chat/badges?broadcaster_id=#{channel_id}") do |req|
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
            p "Badges"
        when 400
            p "bad request"
        when 401
            p "Unauthorized"
        when 429
            p "Too many requests"
        else
            p "something wrong"
        end
    end

    return rep
end

#function to get the global badges
def get_global_badge()
    response = $APItwitch.get("/helix/chat/badges/global") do |req|
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
        p "Global badges"
    when 400
        p "bad request"
    when 401
        p "Unauthorized"
    when 429
        p "Too many requests"
    else
        p "something wrong"
    end

    return rep
end

#function to ban a user
def ban_user(user_name, duration, reason)
    user_exists = false
    user = getTwitchUser(user_name)
    duration = duration * 60
    pre_data = {}
    begin
        pre_data["user_id"] = user["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
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
        response = $APItwitch.post("/helix/moderation/bans?broadcaster_id=#{@me_id}&moderator_id=#{@me_id}", data) do |req|
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
            p "User banned"
        when 400
            p "bad request"
        when 403
            p "Forbidden"
        when 429
            p "Too many requests"
        when 409
            p "conflict"
        when 401
            p "Unauthorized"
        else
            p "something wrong"
        end
    end

    return rep

end

#function to unban a user
def unban_user(user_name)
    user_exists = false
    begin
        user_id = getTwitchUser(user_name)["data"][0]["id"]
        user_exists = true
    rescue
        rep = "user doesn't exist"
    end
    if user_exists == true
        response = $APItwitch.delete("/helix/moderation/bans?broadcaster_id=#{@me_id}&moderator_id=#{@me_id}&user_id#{user_id}") do |req|
            req.headers["Authorization"] = "Bearer #{@token}"
            req.headers["Client-Id"] = @twitch_bot_id
        end
        
        begin
            rep = JSON.parse(response.body)
        rescue
            rep = response.body
        end

        case response.status
        when 204
            p "User unbanned"
        when 400
            p "bad request"
        when 403
            p "Forbidden"
        when 429
            p "Too many requests"
        when 409
            p "conflict"
        when 401
            p "Unauthorized"
        else
            p "something wrong"
        end
    end

    return rep
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
        response = $APItwitch.post("/helix/moderation/vips?broadcaster_id=#{@me_id}&user_id=#{user_id}") do |req|
            req.headers["Authorization"] = "Bearer #{@token}"
            req.headers["Client-Id"] = @twitch_bot_id
        end

        case response.status
        when 204
            rep = "User added to VIP"
        when 400
            rep = "bad request"
        when 403
            rep = "Forbidden"
        when 429
            rep = "Too many requests"
        when 422
            rep = "Unprocessable Entity"
        when 425
            rep = "Too Early"
        when 409
            rep = "conflict"
        when 401
            rep = "Unauthorized"
        else
            rep = "something wrong"
        end
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
        response = $APItwitch.delete("/helix/moderation/vips?broadcaster_id=#{@me_id}&user_id=#{user_id}") do |req|
            req.headers["Authorization"] = "Bearer #{@token}"
            req.headers["Client-Id"] = @twitch_bot_id
        end

        case response.status
        when 204
            rep = "User removed from VIP"
        when 400
            rep = "bad request"
        when 403
            rep = "Forbidden"
        when 429
            rep = "Too many requests"
        when 422
            rep = "Unprocessable Entity"
        when 425
            rep = "Too Early"
        when 409
            rep = "conflict"
        when 401
            rep = "Unauthorized"
        else
            rep = "something wrong"
        end
    end

    return rep
end

def send_message(channel, message)
    channel_exists = false
    begin
        channel_id = getTwitchUser(channel)["data"][0]["id"]
        channel_exists = true
    rescue
        rep = "channel doesn't exist"
    end
    if channel_exists == true
        request_body = {
            "broadcaster_id": channel_id,
            "sender_id": @me_id,
            "message": message
        }.to_json
        sleep(1)
        response = $APItwitch.post("/helix/chat/messages", request_body) do |req|
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
            p "message sent"
        when 400
            p "bad request"
        when 403
            p "Forbidden"
        when 429
            p "Too many requests"
        when 422
            p "Unprocessable Entity"
        when 409
            p "conflict"
        when 401
            p "Unauthorized"
        else
            p "something wrong"
        end
    end
    return rep
end
#######################################################################################

def treat_commands(data)
    first_frag = data["payload"]["event"]["message"]["fragments"][0]
    if first_frag["type"] == "text"
        words = first_frag["text"].split(" ")
        case words[0]
        when "!color"
            color = words[1]
            if color.match?(/^#[0-9A-F]{6}$/i)
                color = color.delete_prefix("#")
                change_color2(color)
            end
        when "!rainbow"
            rainbow_on_off()
        when "!dum"
            dum_on_off()
        when "!discord"
            shareDiscord()
        end
    end
end

def shareDiscord()
    send_message("venorrak", "Join the discord server: https://discord.gg/ydJ7NCc8XM")
end

def jake_ror2(data)
    if data["payload"]["event"]["broadcaster_user_login"] == "jakecreatesstuff"
        if data["payload"]["event"]["chatter_user_login"] == "jakecreatesstuff"
            if data["payload"]["event"]["message"]["text"].start_with?("Chest opened! ")
                text = data["payload"]["event"]["message"]["text"].delete_prefix("Chest opened! ")
                begin
                    text.delete_suffix!(" \u{E0000}")
                end
                choices = text.split(" | ")
                choices.length.times do |i|
                    choices[i] = choices[i].delete_prefix("#{i + 1}: ")
                end
                categories = [
                    [
                        "Delicate Watch",
                        "Warbanner",
                        "Stun Grenade",
                        "Repulsion Armor Plate",
                        "Power Elixir",
                        "Bison Steak",
                        "Oddly-shaped Opal",
                        "Bundle of Fireworks",
                        "Ghor's Tome",
                        "Old War Stealthkit",
                        "Bottled Chaos",
                        "Defensive Microbots",
                        "H3AD-5T v2",
                        "Defense Nucleus",
                        "Planula",
                        "Titanic Knurl",
                        "Pearl",
                        "Queen's Gland",
                        "Voidsent Flame",
                        "Safer Spaces",
                        "Eccentric Vase",
                        "Blast Shower",
                        "Foreign Fruit",
                        "Radar Scanner",
                        "The Crowdfunder",
                        "Gnarled Woodsprite",
                        "Jade Elephant",
                        "Milky Chrysalis",
                        "Spinel Tonic",
                        "Glowing Meteorite",
                        "Stone Flux Pauldron",
                        "Eulogy Zero",
                        "Light Flux Pauldron",
                        "Shared Design",
                        "Beads of Fealty"
                    ],
                    [
                        "Cautious Slug",
                        "Monster Tooth",
                        "Sticky Bomb",
                        "Personal Shield Generator",
                        "Roll of Pennies",
                        "Lepton Daisy",
                        "Squid Polyp",
                        "Razorwire",
                        "Rose Buckler",
                        "Shuriken",
                        "War Horn",
                        "Spare Drone Parts",
                        "Brainstalks",
                        "Happiest Mask",
                        "Sentient Meat Hook",
                        "Little Disciple",
                        "Genesis Loop",
                        "Empathy Cores",
                        "Halcyon Seed",
                        "Pluripotent Larva",
                        "Lost Seer's Lenses",
                        "Tentabauble",
                        "Benthic Bloom",
                        "Forgive Me Please",
                        "Molotov (6-Pack)",
                        "The Back-up",
                        "Executive Card",
                        "Super Massive Leech",
                        "Volcanic Egg",
                        "Effigy of Grief",
                        "Essence of Heresy",
                        "Egocentrism",
                        "Visions of Heresy"
                    ],
                    [
                        "Armor-Piercing Rounds",
                        "Energy Drink",
                        "Rusted Key",
                        "Fuel Cell",
                        "Wax Quail",
                        "Infusion",
                        "Predatory Instincts",
                        "Regenerating Scrap",
                        "Red Whip",
                        "Harvester's Scythe",
                        "Berzerker's Pauldron",
                        "Aegis",
                        "Ben's Raincoat",
                        "N'kuhana's Opinion",
                        "Resonance Disc",
                        "Hardlight Afterburner",
                        "Mired Urn",
                        "Molten Perforator",
                        "Needletick",
                        "Goobo Jr.",
                        "Recycler",
                        "Disposable Missile Launcher",
                        "Ocular HUD",
                        "Sawmerang",
                        "Helfire Tincture",
                        "Defiant Gouge",
                        "Corpsebloom",
                        "Hooks of Heresy",
                        "Mercurial Rachis",
                        "Brittle Crown",
                        "Strides of Heresy",
                        "Purity"
                    ],
                    [
                        "Bustling Fungus",
                        "Medkit",
                        "Mocha",
                        "Soldier's Syringe",
                        "Crowbar",
                        "Topaz Brooch",
                        "Hopoo Feather",
                        "Kjaro's Band",
                        "Runald's Band",
                        "Will-o'-the-wisp",
                        "Bandolier",
                        "Hunter's Harpoon",
                        "Old Guillotine",
                        "Leeching Seed",
                        "Chronobauble",
                        "Death Mark",
                        "Alien Head",
                        "Pocket I.C.B.M.",
                        "Shattering Justice",
                        "Ceremonial Dagger",
                        "Unstable Tesla Coil",
                        "Lysate Cell",
                        "Singularity Band",
                        "Encrusted Key",
                        "Newly Hatched Zoea",
                        "Gorag's Opus",
                        "Preon Accumulator",
                        "Transcendence",
                        "Shaped Glass",
                        "Focused Convergence"
                    ],
                    [
                        "Dio's Best Friend",
                        "Focus Crystal",
                        "Gasoline",
                        "Backup Magazine",
                        "Lens-Maker's Glasses",
                        "Tougher Times",
                        "Paul's Goat Hoof",
                        "Tri-Tip Dagger",
                        "Ignition Tank",
                        "Ukulele",
                        "Shipping Request Form",
                        "AtG Missile Mk. 1",
                        "57 Leaf Clover",
                        "Brilliant Behemoth",
                        "Frost Relic",
                        "Interstellar Desk Plant",
                        "Rejuvenation Rack",
                        "Symbiotic Scorpion",
                        "Soulbound Catalyst",
                        "Wake of Vultures",
                        "Laser Scope",
                        "Plasma Shrimp",
                        "Weeping Fungus",
                        "Polylute",
                        "Shatterspleen",
                        "Charged Perforator",
                        "Trophy Hunter's Tricorn",
                        "Primordial Cube",
                        "Royal Capacitor",
                        "Gesture of the Drowned",
                        "Irradiant Pearl"
                    ]
                ]
                results = [nil, nil, nil]
                categories.each do |category|
                    category.each do |item|
                        choices.each do |choice|
                            if item.downcase == choice.downcase
                                results[choices.index(choice)] = categories.index(category)
                            end
                        end
                    end
                end
                results.each do |result|
                    if result.nil?
                        results[results.index(result)] = 6
                    end
                end
                show = {}
                choices.each do |choice|
                    show[choice] = results[choices.index(choice)]
                end
                ap show
                lowest_number_index = results.index(results.min)

                rep = send_message("jakecreatesstuff", "#{lowest_number_index + 1}")
            end
        end
    end
end

def subscibe_to_jake_chat(session_id)
    channel_id = getTwitchUser("jakecreatesstuff")["data"][0]["id"]
    data = {
        "type" => "channel.chat.message",
        "version" => "1",
        "condition" => {
            "broadcaster_user_id" => channel_id,
            "user_id" => @me_id
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

#######################################################################################

getAccess()
@me_id = getTwitchUser("venorrak")["data"][0]["id"]

Thread.start do
    loop do
        sleep(7000)
        @token = getAccess()
    end
end

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
                #subscibe_to_jake_chat(data["payload"]["session"]["id"])
            end
            if data["metadata"]["message_type"] == "notification"
                case data["payload"]["subscription"]["type"]
                when "channel.follow"
                    msg = {
                        "name": "Follow",
                        "name_color": "#ffd000",
                        "message": "#{data["event"]["user_name"]} has followed",
                        "type": "notif"
                    }
                    writeToJSON(msg)

                when "channel.chat.message"
                    message = []
                    data["payload"]["event"]["message"]["fragments"].each do |frag|
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
                    registered = false
                    pfp_url = ""
                    list = JSON.parse(File.read(File.join(__dir__, "chat/pfp.json")))
                    list.each do |pfp|
                        if pfp["name"] == data["payload"]["event"]["chatter_user_login"]
                            registered = true
                            pfp_url = pfp["url"]
                            break
                        end
                    end
                    if registered == false
                        pfp_url = getTwitchUser(data["payload"]["event"]["chatter_user_login"])["data"][0]["profile_image_url"]
                        list.push({
                            "name": data["payload"]["event"]["chatter_user_login"],
                            "url": pfp_url
                        })
                        File.write("chat/pfp.json", list.to_json)
                    end

                    msg = {
                        "name": data["payload"]["event"]["chatter_user_name"],
                        "name_color": data["payload"]["event"]["color"],
                        "profile_image_url": pfp_url,
                        "message": message,
                        "type": "default"
                    }
                    writeToJSON(msg)
                    treat_commands(data)
                    #jake_ror2(data)

                when "channel.ad_break.begin"
                    msg = {
                        "name": "Ad Break",
                        "name_color": "#ff0000",
                        "message": "ads playing for #{data["event"]["duration_seconds"]} seconds",
                        "type": "negatif"
                    }
                    writeToJSON(msg)

                when "channel.subscribe"
                    if data["event"]["is_gift"] == false
                        msg = {
                            "name": "Subscribe",
                            "name_color": "#00ff00",
                            "message": "#{data["event"]["user_name"]} has subscribed",
                            "type": "subscribe"
                        }
                        writeToJSON(msg)
                    end
                
                when "channel.subscription.gift"
                    if data["event"]["is_anonymous"] == false
                        msg = {
                            "name": "Gift Sub",
                            "name_color": "#00ff00",
                            "message": "anonymous has gifted #{data["event"]["total"]} subs",
                            "type": "subscribe"
                        }
                    else
                        msg = {
                            "name": "Gift Sub",
                            "name_color": "#00ff00",
                            "message": "#{data["event"]["gifter_name"]} has gifted #{data["event"]["total"]} subs",
                            "type": "subscribe"
                        }
                    end
                    writeToJSON(msg)

                when "channel.subscription.message"
                    msg = {
                        "name": "Resub",
                        "name_color": "#00ff00",
                        "message": "#{data["event"]["user_name"]} has resubscribed \n#{data["event"]["message"]["text"]}",
                        "type": "subscibe"
                    }
                    writeToJSON(msg)

                when "channel.cheer"
                    if data["event"]["is_anonymous"] == false
                        msg = {
                            "name": "Cheers",
                            "name_color": "#e100ff",
                            "message": "#{data["event"]["user_name"]} has cheered #{data["event"]["bits"]} bits",
                            "type": "cheer"
                        }
                    else
                        msg = {
                            "name": "Cheers",
                            "name_color": "#e100ff",
                            "message": "anonymous has cheered #{data["event"]["bits"]} bits",
                            "type": "cheer"
                        }
                    end
                    writeToJSON(msg)

                when "channel.raid"
                    msg = {
                        "name": "Raid",
                        "name_color": "#00ccff",
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

