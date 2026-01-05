require "bundler/inline"
require "json"
require 'faye/websocket'
require 'eventmachine'
require "awesome_print"
$bus = nil



def main_menu()
  choices = [
    "token.twitch",
    "token.spotify",
    "spotify.song.start",
    "twitch.raid",
    "twitch.cheer",
    "twitch.sub.resub",
    "twitch.sub.gift",
    "twitch.sub",
    "twitch.ads.begin",
    "twitch.message",
    "twitch.follow",
    "joel.received",
  ]
  system('clear')
  choices.each_with_index do |choice, index|
      puts("#{index + 1}. #{choice}")
  end
  print('Enter your choice: ')
  choice = gets.chomp.to_i
  p choice
  case choice
  when 1
    sendToBus(["token", "twitch"], {
      "status": "refreshed"
    })
    main_menu()
  when 2
    sendToBus(["token", "spotify"], {
      "status": "refreshed"
    })
    main_menu()
  when 3
    sendToBus(["spotify", "song", "start"], {
      "title": "Test Song",
      "artist": "Test Artist",
      "image": "https://venorrak.dev/pictures/Joel.jpg",
      "duration_ms": 300000,
    })
    main_menu()
  when 4
    sendToBus(["twitch", "raid"], {
      "name": "le gars",
      "count": 121
    })
    main_menu()
  when 5
    sendToBus(["twitch", "cheer"], {
      "name": "le gars",
      "count": 100,
      "anonymous": false,
    })
    main_menu()
  when 6
    sendToBus(["twitch", "sub", "resub"], {
      "name": "le gars",
      "message": "Merci pour le sub !",
    })
    main_menu()
  when 7
    sendToBus(["twitch", "sub", "gift"], {
      "name": "le gars",
      "count": 5,
      "anonymous": false,
    })
    main_menu()
  when 8
    sendToBus(["twitch", "sub"], {
      "name": "le gars",
    })
    main_menu()
  when 9
    sendToBus(["twitch", "ads", "begin"], {
      "duration": 30,
    })
    main_menu()
  when 10
    sendToBus(["twitch", "message"], {
      "name": "nameOfPerson",
      "name_color": "#FF0000", #hex color
      "message": [
          {
              "type": "text",
              "content": "testallo"
          }
      ],
      "pfp": "https://venorrak.dev/pictures/Joel.jpg",
      "badges": [], #IDK go check twitch docs
      "raw_message": "messageAsAString"
    })
    main_menu()
  when 11
    sendToBus(["twitch", "follow"], {
      "name": "le gars",
    })
    main_menu()
  when 12
    sendToBus(["joel", "received"], {
      "channel": "Venorrak",
      "user": "Venorrak",
      "count": 2,
      "type": "Joel"
    })
    main_menu()
  else
    puts('Invalid choice')
    sleep(1)
    main_menu()
  end
end

def createMSG(subject, payload)
  return {
    "subject": subject.join("."),
    "payload": payload
  }
end

def sendToBus(subject, payload)
  msg = createMSG(subject, payload)
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

Thread.start do
  EM.run do
    bus = Faye::WebSocket::Client.new('ws://bus:5000')

    bus.on :open do |event|
      p [:open, "BUS"]
      $bus = bus
    end

    bus.on :message do |event|

    end

    bus.on :error do |event|
      p [:error, event.message, "BUS"]
    end

    bus.on :close do |event|
      p [:close, event.code, event.reason, "BUS"]
    end
  end
end

main_menu()