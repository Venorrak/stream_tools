General Structure
```json
{
    "subject": "test.test",
    "payload": {}
}
```
# v.facepoints
payload :
```json
    "landmarks": [floats]
```
# v.audio
payload : 
```json
    "wave": [floats]
```
# v.toggle.splashscreen
payload :
```json
    "enabled": bool
```
# v.toggle.blur
payload :
```json
    "enabled": bool
```
# v.toggle.chat
payload :
```json
    "enabled": bool
```
# command.sendMessage
payload :
```json
{
    "content": "messagetosend"
}
```
# token.twitch
payload :
```json
{
    "status": "refreshed"
}
```
# twitch.raid
payload :
```json
{
    "name": "nameofstreamer",
    "count": 1000, #numberofraiders
}
```
# twitch.cheer
payload :
```json
{
    "name": "nameofcheerer",
    "count": 1000, #nbofcheer
    "anonymous": false #isAnonymous
}
```
# twitch.sub.resub
payload :
```json
{
    "name": "nameOfsubber",
    "message": "subMessage",
}
```
# twitch.sub.gift
payload :
```json
{
    "name": "nameOfperson",
    "count": 1000, #nbOfSubs
    "anonymous": false #isAnonymous
}
```
# twitch.sub
payload :
```json
{
    "name": "nameOfPerson"
}
```
# twitch.ads.begin
payload :
```json
{
    "duration": 1000 #timeinsecs
}
```
# twitch.message
payload :
```json
{
    "name": "nameOfPerson",
    "name_color": "colorOfName",
    "message": [
        {
            "type": "text",
            "content": "testallo"
        },
        {
            "type": "emote",
            "id": "emoteID"
        }
    ],
    "pfp": "urlToPFP",
    "badges": [], #IDK go check twitch docs
    "raw_message": "messageAsAString"
}
```
# twitch.follow
payload :
```json
{
    "name": "NameOfPerson"
}
```
# joel.received
payload :
```json
{
    "channel": "NameOfChannel",
    "user": "NameOfTheJoeler",
    "count": 100, #nbOfJoels
    "type": "typeOfTheLastJoelSaid"
}
```