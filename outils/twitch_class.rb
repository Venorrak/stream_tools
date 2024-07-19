class Twitch
  def initialize(twitch_bot_id, twitch_token_password)

    $twitch_bot_id = twitch_bot_id
    $twitch_token_password = twitch_token_password

    $APItwitch = Faraday.new(url: "https://api.twitch.tv") do |conn|
      conn.request :url_encoded
    end

    $emotes_conn = Faraday.new(url: "https://static-cdn.jtvnw.net") do |conn|
      conn.request :url_encoded
    end

    $myServer = Faraday.new(url: "http://192.168.0.16:6543") do |conn|
      conn.request :url_encoded
    end

    $token = nil
    $me_id = nil
    getAccess()

    $me_id = getTwitchUser("venorrak")["data"][0]["id"]
  end
  
  FILEJSON = "chat/chat.json"

  def do_sleep(x = 1)
    sleep(x)
  end

  #get token from the server
  def getAccess()
    response = $myServer.get("/") do |req|
      req.headers["Authorization"] = $twitch_token_password
    end
    rep = JSON.parse(response.body)
    $token = rep["token"]
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

  #function to write the data to the JSON file
  def writeToJSON(data)
    list = JSON.parse(File.read(File.join(__dir__, FILEJSON)))
    list.push(data)
    File.write(FILEJSON, list.to_json)
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
        req.headers["Client-Id"] = $twitch_bot_id
        req.headers["Content-Type"] = "application/json"
    end
    return JSON.parse(response.body)
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
  def get_viewers()
    response = $APItwitch.get("/helix/chat/chatters?broadcaster_id=#{$me_id}&moderator_id=#{$me_id}") do |req|
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