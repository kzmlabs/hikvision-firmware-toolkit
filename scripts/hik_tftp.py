"""
Hikvision TFTP Recovery Server
Binds to a specific IP and handles the Hikvision handshake protocol.
Based on scottlamb/hikvision-tftpd

Usage: python hik_tftp.py [server_ip] [firmware_file]
Default: python hik_tftp.py 192.168.1.128 digicap.dav
"""

import socket
import struct
import sys
import os
import time
import threading

TFTP_PORT = 69
HANDSHAKE_PORT = 9978
HANDSHAKE_REPLY_PORT = 9979
BLOCK_SIZE = 512

def tftp_server(server_ip, firmware_path):
    """Handle TFTP read requests"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((server_ip, TFTP_PORT))
    sock.settimeout(5)
    print(f"[TFTP] Listening on {server_ip}:{TFTP_PORT}")

    firmware_data = open(firmware_path, 'rb').read()
    firmware_size = len(firmware_data)
    print(f"[TFTP] Firmware loaded: {firmware_size} bytes ({firmware_size/1024/1024:.1f} MB)")

    while True:
        try:
            data, addr = sock.recvfrom(1024)
        except socket.timeout:
            continue
        except Exception as e:
            continue

        opcode = struct.unpack('!H', data[:2])[0]

        if opcode == 1:  # RRQ (Read Request)
            filename = data[2:data.index(b'\x00', 2)].decode()
            print(f"[TFTP] Read request from {addr[0]}:{addr[1]} for '{filename}'")

            # Send file in 512-byte blocks
            block = 1
            offset = 0
            transfer_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            transfer_sock.settimeout(5)

            while offset < firmware_size:
                chunk = firmware_data[offset:offset + BLOCK_SIZE]
                pkt = struct.pack('!HH', 3, block) + chunk  # DATA opcode=3
                transfer_sock.sendto(pkt, addr)

                # Wait for ACK
                retries = 0
                while retries < 5:
                    try:
                        ack_data, ack_addr = transfer_sock.recvfrom(1024)
                        ack_opcode = struct.unpack('!H', ack_data[:2])[0]
                        ack_block = struct.unpack('!H', ack_data[2:4])[0]
                        if ack_opcode == 4 and ack_block == block:
                            break
                    except socket.timeout:
                        print(f"[TFTP] Resend block {block}")
                        transfer_sock.sendto(pkt, addr)
                        retries += 1

                if retries >= 5:
                    print(f"[TFTP] Transfer failed at block {block}")
                    break

                offset += BLOCK_SIZE
                block += 1

                # Progress
                if block % 1000 == 0:
                    pct = offset * 100 // firmware_size
                    print(f"[TFTP] Progress: {pct}% ({offset}/{firmware_size})")

            transfer_sock.close()
            if offset >= firmware_size:
                print(f"[TFTP] Transfer complete! Sent {firmware_size} bytes")
                print(f"[TFTP] Camera should reboot in 3-5 minutes. DO NOT UNPLUG!")
            else:
                print(f"[TFTP] Transfer incomplete")

        elif opcode == 4:  # ACK
            pass


def handshake_server(server_ip):
    """Handle Hikvision's custom handshake on port 9978"""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((server_ip, HANDSHAKE_PORT))
    sock.settimeout(5)
    print(f"[HANDSHAKE] Listening on {server_ip}:{HANDSHAKE_PORT}")

    reply_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    while True:
        try:
            data, addr = sock.recvfrom(1024)
            print(f"[HANDSHAKE] Received {len(data)} bytes from {addr[0]}:{addr[1]}")
            # Echo the packet back to the client's port 9979
            reply_sock.sendto(data, (addr[0], HANDSHAKE_REPLY_PORT))
            print(f"[HANDSHAKE] Replied to {addr[0]}:{HANDSHAKE_REPLY_PORT}")
        except socket.timeout:
            continue
        except Exception as e:
            continue


if __name__ == "__main__":
    server_ip = sys.argv[1] if len(sys.argv) > 1 else "192.168.1.128"
    firmware = sys.argv[2] if len(sys.argv) > 2 else "digicap.dav"

    # Find firmware file
    search_paths = [
        firmware,
        os.path.join(os.path.dirname(__file__), '..', 'firmware', 'hikvision_tftp', 'TFTP', firmware),
        os.path.join(os.path.dirname(__file__), '..', 'firmware', firmware),
    ]

    firmware_path = None
    for p in search_paths:
        if os.path.exists(p):
            firmware_path = os.path.abspath(p)
            break

    if not firmware_path:
        print(f"ERROR: Cannot find {firmware}")
        sys.exit(1)

    print("=" * 50)
    print("Hikvision TFTP Recovery Server")
    print("=" * 50)
    print(f"Server IP: {server_ip}")
    print(f"Firmware:  {firmware_path}")
    print(f"Size:      {os.path.getsize(firmware_path)/1024/1024:.1f} MB")
    print("=" * 50)
    print("Power cycle the camera now!")
    print("=" * 50)

    # Start handshake server in background
    t = threading.Thread(target=handshake_server, args=(server_ip,), daemon=True)
    t.start()

    # Run TFTP server in foreground
    tftp_server(server_ip, firmware_path)
