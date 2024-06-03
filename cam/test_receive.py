import socket
import json

HOST = "127.0.0.1"
PORT = 12345


def main():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((HOST, PORT))

    while True:
        data, addr = sock.recvfrom(8300)
        print(addr)
        msg = data.decode()
        #print(msg)
        landmarks = json.loads(msg)
        #`print(landmarks)

if __name__ == '__main__':
    main()