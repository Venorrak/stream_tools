require "bundler/inline"
require "json"
require 'eventmachine'
require 'absolute_time'
require "awesome_print"
require 'websocket-eventmachine-server'

$WsClients = []

##### UTILS #####

def createMSG(subject, payload)
  return {
    "subject": subject.join("."),
    "payload": payload
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
  puts "#{Time.now().to_s.split(" ")[1]} - #{msg["subject"]} : #{msg["payload"]}"
end


EM.run do
  WebSocket::EventMachine::Server.start(:host => "0.0.0.0", :port => 5000) do |ws|
    ws.onopen do
      $WsClients.push(ws)
      sendToAllClients(createMSG(["BUS"], {"message": "New client connected"}))
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