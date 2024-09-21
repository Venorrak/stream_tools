require "bundler/inline"
require "json"
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require 'websocket-eventmachine-server'

$WsClients = []

##### UTILS #####

def createMSG(from, to, data)
  return {
    "from": from,
    "to": to,
    "time": "#{Time.now().to_s.split(" ")[1]}",
    "payload": data
  }
end

def createMSGTwitch(name, name_color, message, type)
  return {
    "name": name,
    "name_color": name_color,
    "message": message,
    "type": type
  }
end

def sendToAllClients(msg)
  if msg.is_a?(Hash)
    msg = msg.to_json
  end
  printBus(msg)
  $WsClients.each do |client|
    client.send(msg)
  end
end

def printBus(msg)
  begin
    msg = JSON.parse(msg)
  rescue
    p msg
    return
  end
  puts "#{msg["time"] || Time.now().to_s.split(" ")[1]} - #{msg["from"]} to #{msg["to"]} : #{msg["payload"]}"
end


EM.run do
  WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 5963) do |ws|
    ws.onopen do
      $WsClients.push(ws)
      sendToAllClients(createMSG("BUS", "BUS", "New client connected"))
    end

    ws.onmessage do |msg|
      sendToAllClients(msg)
    end

    ws.onclose do
      $WsClients.delete(ws)
      ws.close
    end

    ws.onerror do |e|
      ap e
    end
  end
end