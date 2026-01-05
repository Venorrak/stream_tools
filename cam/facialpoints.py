import cv2
import numpy as np
import mediapipe as mp
import time

def getXY(pt):
    width = 1280
    height = 720
    return [int(pt.x * width), int(pt.y * height)]

def showFace(res, frame, width, height):
    for face_landmarks in res.multi_face_landmarks:
        for i in range(0, 478):
            pt1 = face_landmarks.landmark[i]
            x = int(pt1.x * width)
            y = int(pt1.y * height)
            cv2.circle(frame, (x, y), 1, (0, 255, 0), -1)
    cv2.imshow("Keypoints", frame)
    
def findPositions(cap, face_mesh, body_mesh):
    ret, frame = cap.read()
    width = 1280
    height = 720
    size = (width, height)
    frame = cv2.resize(frame, size, interpolation= cv2.INTER_LINEAR)
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    res = face_mesh.process(rgb_frame)
    res2 = body_mesh.process(rgb_frame)
    face_points = {}
    if res.multi_face_landmarks is not None:
        face_points = {
            "left_eye":[
                getXY(res.multi_face_landmarks[0].landmark[159]),
                getXY(res.multi_face_landmarks[0].landmark[158]),
                getXY(res.multi_face_landmarks[0].landmark[157]),
                getXY(res.multi_face_landmarks[0].landmark[173]),
                getXY(res.multi_face_landmarks[0].landmark[133]),
                getXY(res.multi_face_landmarks[0].landmark[155]),
                getXY(res.multi_face_landmarks[0].landmark[154]),
                getXY(res.multi_face_landmarks[0].landmark[153]),
                getXY(res.multi_face_landmarks[0].landmark[145]),
                getXY(res.multi_face_landmarks[0].landmark[144]),
                getXY(res.multi_face_landmarks[0].landmark[163]),
                getXY(res.multi_face_landmarks[0].landmark[7]),
                getXY(res.multi_face_landmarks[0].landmark[33]),
                getXY(res.multi_face_landmarks[0].landmark[246]),
                getXY(res.multi_face_landmarks[0].landmark[161]),
                getXY(res.multi_face_landmarks[0].landmark[160]),
            ],
            "right_eye":[
                getXY(res.multi_face_landmarks[0].landmark[386]),
                getXY(res.multi_face_landmarks[0].landmark[387]),
                getXY(res.multi_face_landmarks[0].landmark[388]),
                getXY(res.multi_face_landmarks[0].landmark[466]),
                getXY(res.multi_face_landmarks[0].landmark[263]),
                getXY(res.multi_face_landmarks[0].landmark[249]),
                getXY(res.multi_face_landmarks[0].landmark[390]),
                getXY(res.multi_face_landmarks[0].landmark[373]),
                getXY(res.multi_face_landmarks[0].landmark[374]),
                getXY(res.multi_face_landmarks[0].landmark[380]),
                getXY(res.multi_face_landmarks[0].landmark[381]),
                getXY(res.multi_face_landmarks[0].landmark[382]),
                getXY(res.multi_face_landmarks[0].landmark[362]),
                getXY(res.multi_face_landmarks[0].landmark[398]),
                getXY(res.multi_face_landmarks[0].landmark[384]),
                getXY(res.multi_face_landmarks[0].landmark[385]),
            ],
            "shape":[
                getXY(res.multi_face_landmarks[0].landmark[10]),
                getXY(res.multi_face_landmarks[0].landmark[338]),
                getXY(res.multi_face_landmarks[0].landmark[297]),
                getXY(res.multi_face_landmarks[0].landmark[332]),
                getXY(res.multi_face_landmarks[0].landmark[284]),
                getXY(res.multi_face_landmarks[0].landmark[251]),
                getXY(res.multi_face_landmarks[0].landmark[389]),
                getXY(res.multi_face_landmarks[0].landmark[356]),
                getXY(res.multi_face_landmarks[0].landmark[454]),
                getXY(res.multi_face_landmarks[0].landmark[323]),
                getXY(res.multi_face_landmarks[0].landmark[361]),
                getXY(res.multi_face_landmarks[0].landmark[288]),
                getXY(res.multi_face_landmarks[0].landmark[397]),
                getXY(res.multi_face_landmarks[0].landmark[379]),
                getXY(res.multi_face_landmarks[0].landmark[400]),
                getXY(res.multi_face_landmarks[0].landmark[377]),
                getXY(res.multi_face_landmarks[0].landmark[152]),
                getXY(res.multi_face_landmarks[0].landmark[148]),
                getXY(res.multi_face_landmarks[0].landmark[176]),
                getXY(res.multi_face_landmarks[0].landmark[149]),
                getXY(res.multi_face_landmarks[0].landmark[150]),
                getXY(res.multi_face_landmarks[0].landmark[136]),
                getXY(res.multi_face_landmarks[0].landmark[172]),
                getXY(res.multi_face_landmarks[0].landmark[58]),
                getXY(res.multi_face_landmarks[0].landmark[132]),
                getXY(res.multi_face_landmarks[0].landmark[93]),
                getXY(res.multi_face_landmarks[0].landmark[234]),
                getXY(res.multi_face_landmarks[0].landmark[127]),
                getXY(res.multi_face_landmarks[0].landmark[162]),
                getXY(res.multi_face_landmarks[0].landmark[21]),
                getXY(res.multi_face_landmarks[0].landmark[54]),
                getXY(res.multi_face_landmarks[0].landmark[103]),
                getXY(res.multi_face_landmarks[0].landmark[67]),
                getXY(res.multi_face_landmarks[0].landmark[109]),
            ],
            "nose":[
                getXY(res.multi_face_landmarks[0].landmark[48]),###
                getXY(res.multi_face_landmarks[0].landmark[115]),
                getXY(res.multi_face_landmarks[0].landmark[220]),
                getXY(res.multi_face_landmarks[0].landmark[45]),
                getXY(res.multi_face_landmarks[0].landmark[4]),
                getXY(res.multi_face_landmarks[0].landmark[275]),
                getXY(res.multi_face_landmarks[0].landmark[440]),
                getXY(res.multi_face_landmarks[0].landmark[344]),
                getXY(res.multi_face_landmarks[0].landmark[278]),###
            ],
            "nose2":[
                getXY(res.multi_face_landmarks[0].landmark[6]),
                getXY(res.multi_face_landmarks[0].landmark[197]),
                getXY(res.multi_face_landmarks[0].landmark[195]),
                getXY(res.multi_face_landmarks[0].landmark[5]),
                getXY(res.multi_face_landmarks[0].landmark[4]),
                getXY(res.multi_face_landmarks[0].landmark[1]),
                getXY(res.multi_face_landmarks[0].landmark[19]),
                getXY(res.multi_face_landmarks[0].landmark[2])###
            ],
            "nose3":[
                getXY(res.multi_face_landmarks[0].landmark[6]),
                getXY(res.multi_face_landmarks[0].landmark[399]),
                getXY(res.multi_face_landmarks[0].landmark[420]),
                getXY(res.multi_face_landmarks[0].landmark[278]),
                getXY(res.multi_face_landmarks[0].landmark[305]),
                getXY(res.multi_face_landmarks[0].landmark[290]),
                getXY(res.multi_face_landmarks[0].landmark[2]),
                getXY(res.multi_face_landmarks[0].landmark[60]),
                getXY(res.multi_face_landmarks[0].landmark[75]),
                getXY(res.multi_face_landmarks[0].landmark[48]),
                getXY(res.multi_face_landmarks[0].landmark[198]),
                getXY(res.multi_face_landmarks[0].landmark[174])

            ],
            "inner_mouth":[
                getXY(res.multi_face_landmarks[0].landmark[13]),
                getXY(res.multi_face_landmarks[0].landmark[312]),
                getXY(res.multi_face_landmarks[0].landmark[311]),
                getXY(res.multi_face_landmarks[0].landmark[310]),
                getXY(res.multi_face_landmarks[0].landmark[415]),
                getXY(res.multi_face_landmarks[0].landmark[292]),
                getXY(res.multi_face_landmarks[0].landmark[324]),
                getXY(res.multi_face_landmarks[0].landmark[318]),
                getXY(res.multi_face_landmarks[0].landmark[402]),
                getXY(res.multi_face_landmarks[0].landmark[317]),
                getXY(res.multi_face_landmarks[0].landmark[14]),
                getXY(res.multi_face_landmarks[0].landmark[87]),
                getXY(res.multi_face_landmarks[0].landmark[178]),
                getXY(res.multi_face_landmarks[0].landmark[88]),
                getXY(res.multi_face_landmarks[0].landmark[95]),
                getXY(res.multi_face_landmarks[0].landmark[78]),
                getXY(res.multi_face_landmarks[0].landmark[191]),
                getXY(res.multi_face_landmarks[0].landmark[80]),
                getXY(res.multi_face_landmarks[0].landmark[81]),
                getXY(res.multi_face_landmarks[0].landmark[82]),
            ],
            "outer_mouth":[
                getXY(res.multi_face_landmarks[0].landmark[0]),
                getXY(res.multi_face_landmarks[0].landmark[267]),
                getXY(res.multi_face_landmarks[0].landmark[269]),
                getXY(res.multi_face_landmarks[0].landmark[270]),
                getXY(res.multi_face_landmarks[0].landmark[409]),
                getXY(res.multi_face_landmarks[0].landmark[291]),
                getXY(res.multi_face_landmarks[0].landmark[375]),
                getXY(res.multi_face_landmarks[0].landmark[321]),
                getXY(res.multi_face_landmarks[0].landmark[405]),
                getXY(res.multi_face_landmarks[0].landmark[314]),
                getXY(res.multi_face_landmarks[0].landmark[17]),
                getXY(res.multi_face_landmarks[0].landmark[84]),
                getXY(res.multi_face_landmarks[0].landmark[181]),
                getXY(res.multi_face_landmarks[0].landmark[91]),
                getXY(res.multi_face_landmarks[0].landmark[146]),
                getXY(res.multi_face_landmarks[0].landmark[61]),
                getXY(res.multi_face_landmarks[0].landmark[185]),
                getXY(res.multi_face_landmarks[0].landmark[40]),
                getXY(res.multi_face_landmarks[0].landmark[39]),
                getXY(res.multi_face_landmarks[0].landmark[37])
            ],
            "left_eyebrow":[
                getXY(res.multi_face_landmarks[0].landmark[66]),
                getXY(res.multi_face_landmarks[0].landmark[107]),
                getXY(res.multi_face_landmarks[0].landmark[55]),
                getXY(res.multi_face_landmarks[0].landmark[65]),
                getXY(res.multi_face_landmarks[0].landmark[52]),
                getXY(res.multi_face_landmarks[0].landmark[53]),
                getXY(res.multi_face_landmarks[0].landmark[46]),
                getXY(res.multi_face_landmarks[0].landmark[63]),
                getXY(res.multi_face_landmarks[0].landmark[105]),
            ],
            "right_eyebrow":[
                getXY(res.multi_face_landmarks[0].landmark[334]),
                getXY(res.multi_face_landmarks[0].landmark[293]),
                getXY(res.multi_face_landmarks[0].landmark[276]),
                getXY(res.multi_face_landmarks[0].landmark[283]),
                getXY(res.multi_face_landmarks[0].landmark[282]),
                getXY(res.multi_face_landmarks[0].landmark[295]),
                getXY(res.multi_face_landmarks[0].landmark[285]),
                getXY(res.multi_face_landmarks[0].landmark[336]),
                getXY(res.multi_face_landmarks[0].landmark[296]),
            ],
            "left_iris": getXY(res.multi_face_landmarks[0].landmark[468]),
            "right_iris": getXY(res.multi_face_landmarks[0].landmark[473])
        }
        showFace(res, frame, width, height)
    if res2.pose_landmarks is not None:
        face_points["shoulders"] = [
            getXY(res2.pose_landmarks.landmark[11]),
            getXY(res2.pose_landmarks.landmark[12]),
            getXY(res2.pose_landmarks.landmark[24]),
            getXY(res2.pose_landmarks.landmark[23]),
        ]
    return face_points

def drawFace(face_points):
    img = np.zeros((720, 1280, 3), np.uint8)
    img[:] = (0, 255, 0)
    try:
        for x in range(0, 2):
            cv2.polylines(img, [np.array(face_points["left_eye"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.polylines(img, [np.array(face_points["right_eye"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.polylines(img, [np.array(face_points["shape"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.polylines(img, [np.array(face_points["nose"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.polylines(img, [np.array(face_points["nose2"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            #cv2.polylines(img, [np.array(face_points["nose3"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.polylines(img, [np.array(face_points["inner_mouth"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            #cv2.polylines(img, [np.array(face_points["outer_mouth"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.polylines(img, [np.array(face_points["left_eyebrow"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.polylines(img, [np.array(face_points["right_eyebrow"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            #cv2.polylines(img, [np.array(face_points["shoulders"])], isClosed=True, color=(255 * x, 255 * x, 255 * x), thickness=(4 - (x*3)))
            cv2.circle(img, (face_points["right_iris"][0], face_points["right_iris"][1]), 2, (0, 0, 0), 2)
            cv2.circle(img, (face_points["left_iris"][0], face_points["left_iris"][1]), 2, (0, 0, 0), 2)
    except:
        pass
    cv2.imshow("face", img)

def ShowHidden(faceDetect, cap):
    ret, frame = cap.read()
    width = 1280
    height = 720
    size = (width, height)
    frame = cv2.resize(frame, size, interpolation= cv2.INTER_LINEAR)
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    res = faceDetect.process(rgb_frame)
    if res.detections is not None:
        for detection in res.detections:
            bboxC = detection.location_data.relative_bounding_box
            ih, iw, _ = frame.shape
            x, y, w, h = int(bboxC.xmin * iw), int(bboxC.ymin * ih), int(bboxC.width * iw), int(bboxC.height * ih)
            cv2.rectangle(frame, (x, y), (x+w, y+h), (0, 0, 0), -1)
    cv2.imshow("Hidden", frame)

def showBlur(cap, face_cascade, side_face_cascade, hupper_body_cascade):
    ret, frame = cap.read()
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    faces = face_cascade.detectMultiScale(gray, 1.1, 4)
    side_faces = side_face_cascade.detectMultiScale(gray, 1.1, 4)
    hupper_bodies = hupper_body_cascade.detectMultiScale(gray, 1.1, 4)
    for (x, y, w, h) in faces:
        roi = frame[y:y+h, x:x+w]
        roi = cv2.GaussianBlur(roi, (99, 99), 30)
        frame[y:y+h, x:x+w] = roi
    for (x, y, w, h) in side_faces:
        roi = frame[y:y+h, x:x+w]
        roi = cv2.GaussianBlur(roi, (99, 99), 30)
        frame[y:y+h, x:x+w] = roi
    for (x, y, w, h) in hupper_bodies:
        roi = frame[y:y+h, x:x+w]
        roi = cv2.GaussianBlur(roi, (99, 99), 30)
        frame[y:y+h, x:x+w] = roi
    cv2.imshow("blur", frame)

def main():
    cap = cv2.VideoCapture(2)
    face_mesh = mp.solutions.face_mesh.FaceMesh(refine_landmarks=True)
    body_mesh = mp.solutions.pose.Pose()
    faceDetect = mp.solutions.face_detection.FaceDetection()
    # face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_frontalface_default.xml')
    # side_face_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_profileface.xml')
    # hupper_body_cascade = cv2.CascadeClassifier(cv2.data.haarcascades + 'haarcascade_upperbody.xml')
    if not (cap.isOpened()):
        cap.release()
        cv2.destroyAllWindows()
        raise IOError("Could not open video device")
    while cap.isOpened():
        face_points = findPositions(cap, face_mesh, body_mesh)
        if face_points == {}:
            face_points = last_face_points
        last_face_points = face_points
        drawFace(face_points)
        #ShowHidden(faceDetect, cap)
        #showBlur(cap, face_cascade, side_face_cascade, hupper_body_cascade)
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

if __name__ == '__main__':
    main()
