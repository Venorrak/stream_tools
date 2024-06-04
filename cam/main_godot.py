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
    return [int(pt.x * width), int(pt.y * height), int(width * pt.z)]

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
        for face_landmarks in res.multi_face_landmarks:
            for i in range(478):
                pt = face_landmarks.landmark[i]
                x = int(pt.x * width)
                y = int(pt.y * height)
                cv2.circle(frame, (x, y), 1, (0, 255, 0), -1)
                if i == 1:
                    cv2.putText(frame, f'{int(width * pt.z)}', (x, y), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 255), 1, cv2.LINE_AA)
                landmarks.append(getXY(pt))
    #cv2.imshow("Keypoints", frame)
    return landmarks

def main():
    cap = cv2.VideoCapture(2)
    face_mesh = mp.solutions.face_mesh.FaceMesh(refine_landmarks=True)

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

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
            sock.sendto(msg.encode("ascii"), (HOST, PORT))

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

if __name__ == '__main__':
    main()