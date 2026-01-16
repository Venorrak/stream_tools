import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import cv2
import numpy as np
import time
import json
import sounddevice as sd
import websockets
import asyncio
from queue import Queue

WS_URL = "ws://192.168.0.152:5000"

# MICROPHONE
VU_COUNT = 16
HEIGHT = 150
FREQ_MAX = 11050.0
MIN_DB = 20

SAMPLE_RATE = 16000
BLOCK_SIZE = 1024

# Queue for passing audio data from callback thread to async loop
audio_queue = Queue(maxsize=2)

def linear_to_db(x):
    # Avoid log(0)
    return 20 * np.log10(max(x, 1e-10))

def clamp(x, min_val, max_val):
    return max(min(x, max_val), min_val)

# === Core spectrum processing ===
def compute_wave(samples):
    wave = [0.0] * VU_COUNT

    # FFT
    fft = np.fft.rfft(samples)
    magnitudes = np.abs(fft)
    freqs = np.fft.rfftfreq(len(samples), 1 / SAMPLE_RATE)

    prev_hz = 0.0

    for i in range(1, VU_COUNT + 1):
        hz = i * FREQ_MAX / VU_COUNT

        idx = np.where((freqs >= prev_hz) & (freqs < hz))[0]

        if len(idx) == 0:
            magnitude = 0.0
        else:
            magnitude = np.mean(magnitudes[idx])

        energy = clamp(
            (MIN_DB + linear_to_db(magnitude)) / MIN_DB,
            0.0,
            1.0
        )

        wave[i - 1] = float(energy * HEIGHT)
        prev_hz = hz

    # Ensure JSON-serializable native floats
    return [float(v) for v in wave]


# === Microphone callback ===
def audio_callback(indata, frames, time, status):
    if status:
        print(status)

    # Convert stereo → mono if needed
    samples = indata[:, 0]

    vu = compute_wave(samples)
    data = {
        "subject": "v.audio",
        "payload": {"wave": vu}
    }

    # Put data in queue (non-blocking, discard if full)
    try:
        audio_queue.put_nowait(data)
    except:
        pass  # Queue full, skip this frame

async def send_audio(msg):
    async with websockets.connect(WS_URL, max_queue=1) as ws:
        await ws.send(msg)
        print("sent sound data")


# CAMERA
def getLandmarks(cap, options):
    FaceLandmarker = mp.tasks.vision.FaceLandmarker
    ret, frame = cap.read()
    width = 1280
    height = 720
    size = (width, height)
    frame = cv2.resize(frame, size, interpolation= cv2.INTER_LINEAR)
    rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    with FaceLandmarker.create_from_options(options) as landmarker:
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        detection_result = landmarker.detect(mp_image)

        landmarks = []
        if detection_result.face_landmarks:
            for i in [123, 352, 8, 200, 159, 145, 468, 33, 133, 386, 374, 473, 362, 263]:
                pt = detection_result.face_landmarks[0][i]
                landmarks.append([
                    float(pt.x * width),
                    float(pt.y * height),
                    float(width * pt.z),
                ])
    return landmarks

#MAIN
async def main():
    print(sd.query_devices())
    model_path = '/home/venorrak/Documents/projects/stream_tools/cam/face_landmarker.task'
    BaseOptions = mp.tasks.BaseOptions
    FaceLandmarkerOptions = mp.tasks.vision.FaceLandmarkerOptions
    VisionRunningMode = mp.tasks.vision.RunningMode
    options = FaceLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=model_path),
        running_mode=VisionRunningMode.IMAGE,
        num_faces=1,
    )

    cap = cv2.VideoCapture(0)
    if not cap.isOpened():
        cap.release()
        cv2.destroyAllWindows()
        raise IOError("Could not open video device")
    last_time = time.time()

    async with websockets.connect(WS_URL, max_queue=1) as ws:
        with sd.InputStream(
            # device="USB Condenser Microphone",
            device="HD Web Camera",
            samplerate=SAMPLE_RATE,
            blocksize=BLOCK_SIZE,
            channels=1,
            callback=audio_callback,
        ):
            while cap.isOpened():
                # Send audio data from queue if available
                while not audio_queue.empty():
                    audio_data = audio_queue.get_nowait()
                    msg = json.dumps(audio_data)
                    await ws.send(msg)

                now_time = time.time()
                if now_time - last_time > 0.005:

                    landmarks = getLandmarks(cap, options)
                    data = {
                        "subject": "v.facepoints",
                        "payload": {"landmarks": landmarks}
                    }

                    if landmarks:
                        msg = json.dumps(data)
                        await ws.send(msg)

                    last_time = now_time

                if cv2.waitKey(1) & 0xFF == ord('q'):
                    break
    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    asyncio.run(main())