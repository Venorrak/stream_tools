class OBS
  def initialize(obs_password)
    @data = nil
    @mic_muted = false
    @obs_password = obs_password
  end

  def obs_request(method, params)
    begin
      Thread.start do
        EM.run do
          ws = Faye::WebSocket::Client.new("ws://192.168.0.29:4455")
          function_called = false

          ws.on :open do |event|
            #p [:open]
          end
          ws.on :message do |event|
            data = JSON.parse(event.data)
            #ap data
            auth_verified = false
            server_version = ""
            begin
              test = data["d"]["authentication"]["challenge"]
            rescue
              auth_verified = true
            end
            if auth_verified == false
              server_version = data["obsWebSocketVersion"]
              auth = build_auth_string(data["d"]["authentication"]["salt"], data["d"]["authentication"]["challenge"], @obs_password)
              msg = {
                "op": 1,
                "d": {
                  "rpcVersion": 1,
                  "authentication": auth,
                  "eventSubscriptions": 1000 
                }
              }.to_json
              ws.send(msg)
            elsif function_called == false
              pack = call_this_function(method, params)
              ws.send(pack.to_json)
              function_called = true
            else
              ws.close
              @data = data
            end
          end
          ws.on :close do |event|
              #p [:close, event.code, event.reason, "obs"]
              ws = nil
          end
        end
      end
    rescue
        puts('OBS server is not running')
    end
  end

  def build_auth_string(salt, challenge, password)
    secret = Base64.strict_encode64(
      Digest::SHA256.digest(
        "#{password}#{salt}"
      )
    )
    auth = Base64.strict_encode64(
      Digest::SHA256.digest(
        secret + challenge
      )
    )
    return auth
  end

  def call_this_function(method, params)
    send(method, *params)
  end

  def process_data(debug = false)
    if debug
      sleep(0.3)
      ap @data
      gets
    else
      sleep(0.3)
      if @data["op"] == 6
        ap [@data["d"]["requestStatus"]["code"], @data["d"]["requestStatus"]["result"], @data["d"]["requestType"]]
      else
        p "not a request response"
        ap @data
      end
      gets
    end
  end

  def get_data()
    return @data
  end

  def get_mic_muted()
    return @mic_muted
  end

  def set_mic_muted(muted)
    @mic_muted = muted
  end
  #################################
  ##         OBS calls           ##
  #################################

  def get_stats()
    return {
      "op": 6,
      "d": {
        "requestType": "GetVersion",
        "requestId": SecureRandom.uuid,
        "requestData": {}
      }
    }
  end

  def get_inputs()
    return {
      "op": 6,
      "d": {
        "requestType": "GetInputList",
        "requestId": SecureRandom.uuid,
        "requestData": {
          "inputKind": nil
        }
      }
    }
  end

  def mute_input(uuid, muted)
    return {
      "op": 6,
      "d": {
        "requestType": "SetInputMute",
        "requestId": SecureRandom.uuid,
        "requestData": {
          "inputUuid": uuid,
          "inputName": nil,
          "inputMuted": muted
        }
      }
    }
  end

  def get_scene_list()
    return {
      "op": 6,
      "d": {
        "requestType": "GetSceneList",
        "requestId": SecureRandom.uuid,
        "requestData": {}
      }
    }
  end

  def get_item_list(scene_name)
    return {
      "op": 6,
      "d": {
        "requestType": "GetSceneItemList",
        "requestId": SecureRandom.uuid,
        "requestData": {
          "sceneName": scene_name
        }
      }
    }
  end

  def get_item_id(item_name, scene_name)
    return {
      "op": 6,
      "d": {
        "requestType": "GetSceneItemId",
        "requestId": SecureRandom.uuid,
        "requestData": {
          "sceneName": scene_name,
          "sourceName": item_name,
          "searchOffset": 0
        }
      }
    }
  end

  def set_item_invisible(scene_name, item_id)
    return {
      "op": 6,
      "d": {
        "requestType": "SetSceneItemEnabled",
        "requestId": SecureRandom.uuid,
        "requestData": {
          "sceneName": scene_name,
          "sceneItemId": item_id,
          "sceneItemEnabled": false
        }
      }
    }
  end

  def set_item_visible(scene_name, item_id)
    return {
      "op": 6,
      "d": {
        "requestType": "SetSceneItemEnabled",
        "requestId": SecureRandom.uuid,
        "requestData": {
          "sceneName": scene_name,
          "sceneItemId": item_id,
          "sceneItemEnabled": true
        }
      }
    }
  end

  def set_current_scene(scene_name)
    return {
      "op": 6,
      "d": {
        "requestType": "SetCurrentProgramScene",
        "requestId": SecureRandom.uuid,
        "requestData": {
          "sceneName": scene_name
        }
      }
    }
  end
end