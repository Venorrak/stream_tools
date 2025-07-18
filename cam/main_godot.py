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

def getLandmarks(cap, face_mesh):
    ret, frame = cap.read()
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
        landmarks = getLandmarks(cap, face_mesh)
        if len(landmarks) > 0:
            #transform landmarks to json
            msg = json.dumps(landmarks)
            #send json to godot with socket
            now_time = time.time()
            if now_time - last_time > 0.00:
                sock.sendto(msg.encode("ascii"), (HOST, PORT))
                last_time = time.time()
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

if __name__ == '__main__':
    main()