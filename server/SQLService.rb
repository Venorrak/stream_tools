require "json"
require 'time'
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem 'sinatra-contrib'
  gem 'rackup'
  gem 'webrick'
  gem "mysql2"
  require 'sinatra'
end

require 'mysql2'

$JoelDB = Mysql2::Client.new(:host => "localhost", :username => "bot", :password => "joel", :reconnect => true, :database => "joelScan", idle_timeout: 0)
$StreamDB = Mysql2::Client.new(:host => "localhost", :username => "bus", :password => "1234", :reconnect => true, :database => "stream", idle_timeout: 0)

# PREPARED STATEMENTS

$StreamNewUser = $StreamDB.prepare("INSERT INTO users (name, twitch_id) VALUES (?, ?);")
$StreamNewPoints = $StreamDB.prepare("INSERT INTO points (user_id, points) VALUES (?, 0);")
$StreamGetUser = $StreamDB.prepare("SELECT * FROM users WHERE twitch_id = ?;")
$StreamAddPoints = $StreamDB.prepare("UPDATE points SET points = points + ? WHERE user_id = ?;")
$StreamRemovePoints = $StreamDB.prepare("UPDATE points SET points = points - ? WHERE user_id = ?;")
$StreamGetPoints = $StreamDB.prepare("SELECT * FROM points WHERE user_id = ?;")
$StreamNewLore = $StreamDB.prepare("INSERT INTO lore (word, count) VALUES (?, 1);")
$StreamUpdateLore = $StreamDB.prepare("UPDATE lore SET count = count + 1 WHERE word = ?;")
$StreamGetLore = $StreamDB.prepare("SELECT * FROM lore WHERE word = ?;")
$StreamGetHighestLore = $StreamDB.prepare("SELECT word, count FROM lore ORDER BY count DESC LIMIT 1;")

$JoelGetTotalJoelCountLastStream = $JoelDB.prepare("SELECT count FROM streamJoels WHERE channel_id = (SELECT id FROM channels WHERE name = ?) ORDER BY streamDate DESC LIMIT 1;") 
$JoelGetJCPlongAll = $JoelDB.prepare("SELECT * FROM JCPlong;")
$JoelNewJCPlong = $JoelDB.prepare("INSERT INTO JCPlong VALUES (DEFAULT, ?, ?);")
$JoelGetJCPshortAll = $JoelDB.prepare("SELECT * FROM JCPshort;")
$JoelNewJCPshort = $JoelDB.prepare("INSERT INTO JCPshort VALUES (DEFAULT, ?, ?);")
$JoelGetLastLongJCP = $JoelDB.prepare("SELECT * FROM JCPlong ORDER BY timestamp DESC LIMIT 1;")
$JoelGetLastShortJCP = $JoelDB.prepare("SELECT * FROM JCPshort ORDER BY timestamp DESC LIMIT 1;")
$JoelDeleteOldShortJCP = $JoelDB.prepare("DELETE FROM JCPshort WHERE timestamp < ?;")
$JoelNewPfp = $JoelDB.prepare("INSERT INTO pictures VALUES (DEFAULT, ?, 'pfp');")
$JoelNewBgp = $JoelDB.prepare("INSERT INTO pictures VALUES (DEFAULT, ?, 'bgp');")
$JoelGetPicture = $JoelDB.prepare("SELECT * FROM pictures WHERE url = ?;")
$JoelNewUser = $JoelDB.prepare("INSERT INTO users VALUES (DEFAULT, ?, ?, ?, ?, ?);")
$JoelGetUser = $JoelDB.prepare("SELECT * FROM users WHERE name = ?;")
$JoelNewJoel = $JoelDB.prepare("INSERT INTO joels VALUES (DEFAULT, ?, ?);")
$JoelUpdateJoel = $JoelDB.prepare("UPDATE joels SET count = count + ? WHERE user_id = (SELECT id FROM users WHERE name = ?);")
$JoelNewChannel = $JoelDB.prepare("INSERT INTO channels VALUES (DEFAULT, ?, ?);")
$JoelGetChannel = $JoelDB.prepare("SELECT * FROM channels WHERE name = ?;")
$JoelNewChannelJoels = $JoelDB.prepare("INSERT INTO channelJoels VALUES (DEFAULT, ?, 1);")
$JoelNewStreamJoels = $JoelDB.prepare("INSERT INTO streamJoels VALUES (DEFAULT, (SELECT id FROM channels WHERE name = ?), 1, ?);")
$JoelUpdateStreamJoels = $JoelDB.prepare("UPDATE streamJoels SET count = count + ? WHERE channel_id = (SELECT id FROM channels WHERE name = ?) AND streamDate = ?;")
$JoelUpdateChannelJoels = $JoelDB.prepare("UPDATE channelJoels SET count = count + ? WHERE channel_id = (SELECT id FROM channels WHERE name = ?);")
$JoelGetStreamJoelsToday = $JoelDB.prepare("SELECT * FROM streamJoels WHERE channel_id = (SELECT id FROM channels WHERE name = ?) AND streamDate = ?;")
$JoelGetStreamUserJoels = $JoelDB.prepare("SELECT streamUsersJoels.user_id, streamUsersJoels.stream_id, channels.name, users.name FROM streamUsersJoels INNER JOIN streamJoels ON streamJoels.id = streamUsersJoels.stream_id INNER JOIN channels ON channels.id = streamJoels.channel_id INNER JOIN users ON users.id = streamUsersJoels.user_id WHERE channels.name = ? AND users.name = ? AND streamJoels.streamDate = ?;")
$JoelUpdateStreamUserJoels = $JoelDB.prepare("UPDATE streamUsersJoels SET count = count + ? WHERE user_id = (SELECT id FROM users WHERE name = ?) AND stream_id = (SELECT id FROM streamJoels WHERE channel_id = (SELECT id FROM channels WHERE name = ?) AND streamDate = ?);")
$JoelNewStreamUserJoel = $JoelDB.prepare("INSERT INTO streamUsersJoels VALUES (DEFAULT, (SELECT id FROM streamJoels WHERE channel_id = (SELECT id FROM channels WHERE name = ?) AND streamDate = ?), (SELECT id FROM users WHERE name = ?), ?);")
$JoelGetUserCount = $JoelDB.prepare("SELECT count FROM joels WHERE user_id = (SELECT id FROM users WHERE name = ?);")
$JoelGetChannelJoels = $JoelDB.prepare("SELECT * FROM channelJoels WHERE channel_id = (SELECT id FROM channels WHERE name = ?);")
$JoelGetTop5Joels = $JoelDB.prepare("SELECT users.name, joels.count FROM users INNER JOIN joels ON users.id = joels.user_id ORDER BY joels.count DESC LIMIT 5;")
$JoelGetTop5JoelsChannel = $JoelDB.prepare("SELECT channels.name, channelJoels.count FROM channels INNER JOIN channelJoels ON channels.id = channelJoels.channel_id ORDER BY channelJoels.count DESC LIMIT 5;")

$JoelGetBasicStats = $JoelDB.prepare("SELECT joels.count as totalJoels, users.creationDate as firstJoelDate FROM users JOIN joels ON users.id = joels.user_id WHERE users.name = ? LIMIT 1;")
$JoelGetMostJoelStreamStats = $JoelDB.prepare("SELECT channels.name as MostJoelsInStreamStreamer, streamUsersJoels.count as mostJoelsInStream, streamJoels.streamDate as mostJoelsInStreamDate FROM users JOIN streamUsersJoels ON users.id = streamUsersJoels.user_id JOIN streamJoels ON streamUsersJoels.stream_id = streamJoels.id JOIN channels ON streamJoels.channel_id = channels.id WHERE users.name = ? AND streamUsersJoels.count = (SELECT MAX(streamUsersJoels.count) FROM streamUsersJoels WHERE user_id = users.id);")
$JoelGetMostJoeledStreamerStats = $JoelDB.prepare("SELECT channels.name as mostJoeledStreamer, CAST(SUM(streamUsersJoels.count) AS INTEGER) as count FROM users JOIN streamUsersJoels ON users.id = streamUsersJoels.user_id JOIN streamJoels ON streamUsersJoels.stream_id = streamJoels.id JOIN channels ON streamJoels.channel_id = channels.id WHERE users.name = ? GROUP BY channels.id ORDER BY count DESC;")

# REFRENCES

$JoelRequestRefrenceList = {
  "GetTotalJoelCountLastStream" => :JoelGetTotalJoelCountLastStream,
  "GetJCPlongAll" => :JoelGetJCPlongAll,
  "NewJCPlong" => :JoelNewJCPlong,
  "GetJCPshortAll" => :JoelGetJCPshortAll,
  "NewJCPshort" => :JoelNewJCPshort,
  "GetLastLongJCP" => :JoelGetLastLongJCP,
  "GetLastShortJCP" => :JoelGetLastShortJCP,
  "DeleteOldShortJCP" => :JoelDeleteOldShortJCP,
  "NewPfp" => :JoelNewPfp,
  "NewBgp" => :JoelNewBgp,
  "GetPicture" => :JoelGetPicture,
  "NewUser" => :JoelNewUser,
  "GetUser" => :JoelGetUser,
  "GetUserArray" => :JoelGetUserArray,
  "NewJoel" => :JoelNewJoel,
  "UpdateJoel" => :JoelUpdateJoel,
  "NewChannel" => :JoelNewChannel,
  "NewChannelJoels" => :JoelNewChannelJoels,
  "GetChannel" => :JoelGetChannel,
  "GetChannelArray" => :JoelGetChannelArray,
  "NewStreamJoels" => :JoelNewStreamJoels,
  "UpdateStreamJoels" => :JoelUpdateStreamJoels,
  "UpdateChannelJoels" => :JoelUpdateChannelJoels,
  "GetStreamJoelsToday" => :JoelGetStreamJoelsToday,
  "GetStreamUserJoels" => :JoelGetStreamUserJoels,
  "UpdateStreamUserJoels" => :JoelUpdateStreamUserJoels,
  "NewStreamUserJoels" => :JoelNewStreamUserJoel,
  "GetUserCount" => :JoelGetUserCount,
  "GetChannelJoels" => :JoelGetChannelJoels,
  "GetTop5Joels" => :JoelGetTop5Joels,
  "GetTop5JoelsChannel" => :JoelGetTop5JoelsChannel,
  "GetBasicStats" => :JoelGetBasicStats,
  "GetMostJoelStreamStats" => :JoelGetMostJoelStreamStats,
  "GetMostJoeledStreamerStats" => :JoelGetMostJoeledStreamerStats,
}

$StreamRequestRefrenceList = {
  "NewUser" => :StreamNewUser,
  "NewPoints" => :StreamNewPoints,
  "GetUser" => :StreamGetUser,
  "AddPoints" => :StreamAddPoints,
  "RemovePoints" => :StreamRemovePoints,
  "GetPoints" => :StreamGetPoints,
  "NewLore" => :StreamNewLore,
  "UpdateLore" => :StreamUpdateLore,
  "GetLore" => :StreamGetLore,
  "GetHighestLore" => :StreamGetHighestLore,
}

# FUNCTIONS

# STREAM

def StreamNewUser(name, twitch_id)
  return $StreamNewUser.execute(name, twitch_id)
end

def StreamNewPoints(user_id)
  return $StreamNewPoints.execute(user_id)
end

def StreamGetUser(twitch_id)
  return $StreamGetUser.execute(twitch_id).first
end

def StreamAddPoints(points, user_id)
  return $StreamAddPoints.execute(points, user_id)
end

def StreamRemovePoints(points, user_id)
  return $StreamRemovePoints.execute(points, user_id)
end

def StreamGetPoints(user_id)
  return $StreamGetPoints.execute(user_id).first
end

def StreamNewLore(word)
  return $StreamNewLore.execute(word)
end

def StreamUpdateLore(word)
  return $StreamUpdateLore.execute(word)
end

def StreamGetLore(word)
  return $StreamGetLore.execute(word).first
end

def StreamGetHighestLore()
  return $StreamGetHighestLore.execute().first
end



# JOEL

def JoelGetTotalJoelCountLastStream(channel_name)
  return $JoelGetTotalJoelCountLastStream.execute(channel_name).first
end

def JoelGetJCPlongAll()
  return $JoelGetJCPlongAll.execute().to_a
end

def JoelNewJCPlong(percentage, timestamp)
  return $JoelNewJCPlong.execute(percentage, timestamp)
end

def JoelGetJCPshortAll()
  return $JoelGetJCPshortAll.execute().to_a
end

def JoelNewJCPshort(percentage, timestamp)
  return $JoelNewJCPshort.execute(percentage, timestamp)
end

def JoelGetLastLongJCP()
  return $JoelGetLastLongJCP.execute().first
end

def JoelGetLastShortJCP()
  return $JoelGetLastShortJCP.execute().first
end

def JoelDeleteOldShortJCP(timestamp)
  return $JoelDeleteOldShortJCP.execute(timestamp)
end

def JoelNewPfp(url)
  return $JoelNewPfp.execute(url)
end

def JoelNewBgp(url)
  return $JoelNewBgp.execute(url)
end

def JoelGetPicture(url)
  return $JoelGetPicture.execute(url).first
end

def JoelNewUser(twitch_id, pfp_id, bgp_id, name, creationDate)
  return $JoelNewUser.execute(twitch_id, pfp_id, bgp_id, name, creationDate)
end

def JoelGetUser(name)
  return $JoelGetUser.execute(name).first
end

def JoelGetUserArray(name)
  return $JoelGetUser.execute(name).to_a
end

def JoelNewJoel(user_id, count)
  return $JoelNewJoel.execute(user_id, count)
end

def JoelUpdateJoel(count, name)
  return $JoelUpdateJoel.execute(count, name)
end

def JoelNewChannel(name, creationDate)
  return $JoelNewChannel.execute(name, creationDate)
end

def JoelGetChannel(name)
  return $JoelGetChannel.execute(name).first
end

def JoelGetChannelArray(name)
  return $JoelGetChannel.execute(name).to_a
end

def JoelNewChannelJoels(channel_name)
  return $JoelNewChannelJoels.execute(channel_name)
end

def JoelNewStreamJoels(channel_name, creationDate)
  return $JoelNewStreamJoels.execute(channel_name, creationDate)
end

def JoelUpdateStreamJoels(count, channel_name, streamDate)
  return $JoelUpdateStreamJoels.execute(count, channel_name, streamDate)
end

def JoelUpdateChannelJoels(count, channel_name)
  return $JoelUpdateChannelJoels.execute(count, channel_name)
end

def JoelGetStreamJoelsToday(channel_name, streamDate)
  return $JoelGetStreamJoelsToday.execute(channel_name, streamDate).first
end

def JoelGetStreamUserJoels(channel_name, user_name, streamDate)
  return $JoelGetStreamUserJoels.execute(channel_name, user_name, streamDate).first
end

def JoelUpdateStreamUserJoels(count, user_name, channel_name, streamDate)
  return $JoelUpdateStreamUserJoels.execute(count, user_name, channel_name, streamDate)
end

def JoelNewStreamUserJoel(channel_name, streamDate, user_name, count)
  return $JoelNewStreamUserJoel.execute(channel_name, streamDate, user_name, count)
end

def JoelGetUserCount(name)
  return $JoelGetUserCount.execute(name).first
end

def JoelGetChannelJoels(channelName)
  return $JoelGetChannelJoels.execute(channelName).first
end

def JoelGetTop5Joels()
  return $JoelGetTop5Joels.execute().to_a
end

def JoelGetTop5JoelsChannel()
  return $JoelGetTop5JoelsChannel.execute().to_a
end

def JoelGetBasicStats(name)
  return $JoelGetBasicStats.execute(name).first
end

def JoelGetMostJoelStreamStats(name)
  return $JoelGetMostJoelStreamStats.execute(name).first
end

def JoelGetMostJoeledStreamerStats(name)
  return $JoelGetMostJoeledStreamerStats.execute(name).first
end

# SINATRA

set :port, 5001
set :bind, '0.0.0.0'

post '/stream/:requestName' do
  requestBody = JSON.parse(request.body.read)
  requestLink = $StreamRequestRefrenceList[params[:requestName]]
  if requestLink.nil?
    return [
      404,
      {},
      "Request not found"
    ]
  end
  begin
    return [
      200,
      {"content-type" => "application/json"},
      send(requestLink, *requestBody).to_json
    ]
  rescue Mysql2::Error::ConnectionError => e
    p e
    restartSQLConnection()
    return [
      500,
      {},
      "Lost connection to MySQL server during query"
    ]
  rescue => e
    p e
    return [
      400,
      {},
      "wrong number of arguments"
    ]
  end
end

post '/joel/:requestName' do
  requestBody = JSON.parse(request.body.read)
  requestLink = $JoelRequestRefrenceList[params[:requestName]]
  if requestLink.nil?
    return [
      404,
      {},
      "Request not found"
    ]
  end
  begin
    return [
      200,
      {"content-type" => "application/json"},
      send(requestLink, *requestBody).to_json
    ]
  rescue Mysql2::Error::ConnectionError => e
    p e
    restartSQLConnection()
    return [
      500,
      {},
      "Lost connection to MySQL server during query"
    ]
  rescue => e
    p e
    return [
      400,
      {},
      "wrong number of arguments"
    ]
  end
end

def restartSQLConnection()
  $JoelDB.close
  $StreamDB.close
  exec("ruby SQLService.rb")
  $JoelDB = Mysql2::Client.new(:host => "localhost", :username => "bot", :password => "joel", :reconnect => true, :database => "joelScan", idle_timeout: 0)
  $StreamDB = Mysql2::Client.new(:host => "localhost", :username => "bus", :password => "1234", :reconnect => true, :database => "stream", idle_timeout: 0)
end