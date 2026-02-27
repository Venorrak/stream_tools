require "bundler/inline"
require "json"
require 'faye/websocket'
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require "openssl"
require 'remove_emoji'
require 'digest'

gemfile do
  source "https://rubygems.org"
  gem "faraday"
end

require "faraday"
require_relative "../secret.rb"
require_relative "TwitchApi.rb"
require_relative "MusicApi.rb"

$bus = nil
$TwitchApi = nil
$MusicApi = nil

$points_last_refresh = AbsoluteTime.now
$points_users_last_scan = []

$TokenService = Faraday.new(url: "http://token:5002") do |conn|
  conn.request :url_encoded
end

##### UTILS #####

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

def handleExternalCommand(keywords, data)
  case keywords[1]
  when "sendMessage"
    send_twitch_message("venorrak", data["content"])
  end
end

##### MAIN #####

$TwitchApi = TwitchApi.new($twitch_bot_id, $twitch_bot_secret, $TokenService)
$MusicApi = MusicApi.new($music_api_password)

$TwitchApi.startThread()

EM.run do
  bus = Faye::WebSocket::Client.new('ws://bus:5000')

  bus.on :open do |event|
    p [:open, "BUS"]
    $bus = bus
  end

  bus.on :message do |event|
    begin
      data = JSON.parse(event.data)
    rescue
      data = event.data
    end
    keywords = data["subject"].split(".")
    case keywords[0]
      when "command"
        handleExternalCommand(keywords, data["payload"])
      when "token"
        case keywords[1]
        when "twitch"
          if data["payload"]["status"] == "refreshed"
            $TwitchApi.getToken()
          end
        end
      end
  end

  bus.on :error do |event|
    p [:error, event.message, "BUS"]
  end

  bus.on :close do |event|
    p [:close, event.code, event.reason, "BUS"]
    exit
  end
end