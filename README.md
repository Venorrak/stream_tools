# Collection of tools I use for streaming

This repository contains scripts that take care of auth with APIs, interactions with multiples databases, communication between different softwares, a "cli" to to controll diffrent scripts and a siple python script to get facial points.

## Index

- [Server](#server)
    - [TokenService](#tokenservicerb)
    - [SQLService](#sqlservicerb)
    - [BUS](#busrb)
    - [API](#apisrb)
- [Utils](#utils)
    - [Cli](#clirb--classes)
    - [Music overlay](#music)
    - [Chat overlay](#chat)
- [Cam](#cam)
    - [Face tracker](#main_godotpy)
    - [Socket Test](#test_receivepy)
- [Other](#other)
    - [Window Manager](#windowmanagerpy)

## Server
### TokenService.rb
Ruby script taking care of maintaining tokens for multiples APIs updated so that other scripts can just fetch it using an http request.

### SQLService.rb
Ruby script that simplifies the use of multiples databases at the same time. Uses a list of prepared request you can just execute with parameters through an http request.

### BUS.rb
Simple ruby script that hosts a websocket used by multiples scripts to communicate with each other

### APIs.rb
Ruby script taking care of multiple little tasks and getting Twitch chat messages before sending them to the BUS.

Littles tasks:
- Getting Twitch chat messages
- Treat chat messages for interactions
- Getting Spotify playback
- Giving virtual points to the viewers

## Utils
### Cli.rb & classes
"Cli" tool being used to control various things like a Godot interface, the OBS websocket, the Spotify API and the Twitch API.
### Music
Old overlay being used to display current played song (now in the godot zone)
### Chat
Old overlay being used to display the Twitch chat (now in the godot zone)

## Cam
### main_godot.py
Simple python script using opencv and mediapipe to get facial tracking points multiple times per second. Those points are being sent to Godot via a UPD port. The data is used to move a model in Godot accordingly.

### test_receive.py
Little script to verify that the facial points are being sent well through the UDP port.

## Other
### windowManager.py
This python scripts interacts with the OBS websocket and tracks the position of multiples windows and move them accordingly in an OBS scene. This is to give the feel of a display-capture while still being a window-capture.