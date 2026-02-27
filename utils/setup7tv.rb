require "bundler/inline"
require "net/http"
require "awesome_print"
require "json"

gemfile do
  source "https://rubygems.org"
  gem "faraday"
end

require "faraday"

$tvApi = Faraday.new(url: "https://7tv.io/") do |conn|
  conn.request :url_encoded
end

$https = Faraday.new(url: "https:") do |conn|
  conn.request :url_encoded
end

def getEmotesList()
  data = $tvApi.get("/v3/emote-sets/66b13fe6f75366de4a6ab184")
  begin
    data = JSON.parse(data.body)
  rescue
    return nil
  end
  emotes = []
  data["emotes"].each do |emote|
    emotes.push({
      "name" => emote["name"],
      "id" => emote["id"],
      "url" => emote["data"]["host"]["url"] + "/1x.webp"
    })
  end
  return emotes
end

def getEmoteData(emote)
  data = $https.get(emote["url"])
  if data.status != 200
    return nil
  end
  File.open("chat/7tv/#{emote["name"]}.webp", 'wb') { |file| file.write(data.body) }
end

emotes = getEmotesList()
emotes.each do |emote|
  getEmoteData(emote)
end

emotes.each do |emote|
  system("convert -dispose previous chat/7tv/#{emote["name"]}.webp chat/7tv/#{emote["name"]}.gif")
  system("rm chat/7tv/#{emote["name"]}.webp")
  sleep(1)
end

File.open("chat/emotes.json", 'w') { |file| file.write((emotes).to_json) }