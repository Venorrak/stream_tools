from deepface import DeepFace
import cv2
import numpy as np
import mediapipe as mp
import time
import json
import socket

HOST = "127.0.0.1"
PORT = 12345

def getXY(pt):
    width = 1280
    height = 720
    return [pt.x * width, pt.y * height, width * pt.z]

def getLandmarks(frame, face_mesh):
    width = 1280
    height = 720
    size = (width, height)
    frame = cv2.resize(frame, size, interpolation= cv2.INTER_LINEAR)
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    res = face_mesh.process(rgb_frame)
    landmarks = []
    if res.multi_face_landmarks:
        for i in [123, 352, 8, 200, 159, 145, 468, 33, 133, 386, 374, 473, 362, 263]:
            pt = res.multi_face_landmarks[0].landmark[i]
            landmarks.append(getXY(pt))
    return landmarks

def getEmotion(frame):
    # Save the frame to a temporary file
    cv2.imwrite("temp_frame.jpg", frame)
    
    # Analyze the emotion
    try:
        result = DeepFace.analyze("temp_frame.jpg", actions=['emotion'])
        emotions = result[0]['emotion']
        # Convert numpy float32 values to regular Python floats for JSON serialization
        emotions = {key: float(value) for key, value in emotions.items()}
        return emotions
    except Exception as e:
        print(f"Error analyzing emotion: {e}")
        return None

def main():
    cap = cv2.VideoCapture(0)
    face_mesh = mp.solutions.face_mesh.FaceMesh(refine_landmarks=True)
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    last_time = time.time()
    
    if not (cap.isOpened()):
        cap.release()
        cv2.destroyAllWindows()
        raise IOError("Could not open video device")
    while cap.isOpened():
        ret, frame = cap.read()
        now_time = time.time()
        if ret:
            landmarks = getLandmarks(frame, face_mesh)
            if now_time - last_time > 1.00:
                last_time = now_time
                emotions = getEmotion(frame)
                if emotions:
                    msg = json.dumps({"type": "emotions", "payload": emotions})
                    sock.sendto(msg.encode("ascii"), (HOST, PORT))
            if len(landmarks) > 0:
                msg = json.dumps({"type": "landmarks", "payload": landmarks})
                sock.sendto(msg.encode("ascii"), (HOST, PORT))
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

if __name__ == '__main__':
    main()