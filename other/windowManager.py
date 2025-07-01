import obswebsocket.exceptions
import win32gui
from win32gui import FindWindow, GetWindowRect
import obswebsocket
from obswebsocket import obsws, requests
import time
import os
from dotenv import load_dotenv

host = "127.0.0.1"
port = 4455
load_dotenv()
password = os.getenv("PASSWORD")

ws = obsws(host, port, password)

obsWindows = []

def updateWindows():
    for obsWindow in obsWindows:
        info = ws.call(requests.GetInputSettings(inputName=obsWindow["obsElementName"]))
        source = info.getInputSettings()["window"]
        parts = source.split(":")
        exe = parts[2]
        name = parts[0]
        if "#3A" in name:
            name = name.replace("#3A", ":")
        nameChanged = True if obsWindow["name"] != name or obsWindow["exe"] != exe else False
        obsWindow["name"] = name
        obsWindow["exe"] = exe
        
        if nameChanged:
            print(name)
            window_handle = FindWindow(None, name)
        else:
            window_handle = obsWindow["hwnd"]
        
        try:
            window_rect = GetWindowRect(window_handle)
        except:
            # exit()
            obsWindow["hwnd"] = None
            continue
        
        obsWindow["hwnd"] = window_handle
        new_pos = {
            "x" : window_rect[0] + 8,
            "y" : window_rect[1] + 8
        }
        if obsWindow["Position"] != new_pos:
            obsWindow["Position"] = new_pos
            ws.call(requests.SetSceneItemTransform(sceneName="spout", sceneItemId=obsWindow["obsItemId"], sceneItemTransform={"positionX": new_pos["x"], "positionY": new_pos["y"]}))

def updateFocusedWindow():
    focusedWindowHWND = win32gui.GetForegroundWindow()
    focusedWindow = next((x for x in obsWindows if x["hwnd"] == focusedWindowHWND), None)
    if not focusedWindow == None:
        ws.call(requests.SetSceneItemIndex(sceneName="spout", sceneItemId=focusedWindow["obsItemId"], sceneItemIndex=100))

def onEvent(message):
    pass

try:
    ws.connect()
    print("connected to websocket")
    
    ws.register(onEvent)
    
    items = ws.call(requests.GetSceneItemList(sceneName="spout"))
    for item in items.getSceneItems():
        obsWindows.append({
            "obsElementName": item["sourceName"],
            "obsItemId": item["sceneItemId"],
            "name": None,
            "exe": None,
            "hwnd": None,
            "Position": None
        })
    
    while True:
        updateWindows()
        updateFocusedWindow()
        time.sleep(0.1)
        
except obswebsocket.exceptions.ConnectionFailure as e:
    print("Couldn't connect to obs")
    print(e)
finally:
    ws.disconnect()
    print("disconnected from websocket")