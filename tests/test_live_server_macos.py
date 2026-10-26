#!/usr/bin/env python3
# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
"""Run the real TCP server with zero USB targets and isolated loopback-only test mode."""
import json
import socket
import struct
import subprocess
import sys
import time
import unittest

BINARY = sys.argv[1] if len(sys.argv) > 1 else 'src/USBAnywhere.Server.Mac/build/usbanywhere-server-mac'


def exact(sock, count):
    data = bytearray()
    while len(data) < count:
        piece = sock.recv(count - len(data))
        if not piece:
            raise EOFError('incomplete USB/IP reply')
        data.extend(piece)
    return bytes(data)


class LiveProtocol(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.process = subprocess.Popen([BINARY, '--protocol-test'])
        for _ in range(100):
            if cls.process.poll() is not None:
                raise RuntimeError('daemon failed to start')
            try:
                with socket.create_connection(('127.0.0.1', 3240), timeout=.2):
                    return
            except OSError:
                time.sleep(.05)
        cls.process.terminate()
        cls.process.wait(timeout=15)
        raise RuntimeError('listener did not become ready')

    @classmethod
    def tearDownClass(cls):
        cls.process.terminate()
        cls.process.wait(timeout=15)

    def connect(self):
        sock = socket.create_connection(('127.0.0.1', 3240), timeout=8)
        self.addCleanup(sock.close)
        return sock

    def test_fragmented_list(self):
        sock = self.connect()
        for byte in struct.pack('>HHI', 0x111, 0x8005, 0):
            sock.sendall(bytes([byte]))
        self.assertEqual(exact(sock, 12), struct.pack('>HHII', 0x111, 5, 0, 0))

    def test_absent_device_import_fails(self):
        sock = self.connect()
        sock.sendall(struct.pack('>HHI', 0x111, 0x8003, 0) + b'1-1'.ljust(32, b'\0'))
        self.assertEqual(exact(sock, 8), struct.pack('>HHI', 0x111, 3, 1))

    def test_bad_version_rejected(self):
        sock = self.connect()
        sock.sendall(struct.pack('>HHI', 0x110, 0x8005, 0))
        self.assertEqual(sock.recv(1), b'')

    def test_partial_request_deadline_and_listener_survives(self):
        sock = self.connect()
        sock.sendall(b'\x01')
        self.assertEqual(sock.recv(1), b'')
        self.assertIsNone(self.process.poll())
        self.test_fragmented_list()

    def test_unknown_bus_refused(self):
        sock = self.connect()
        sock.sendall(struct.pack('>HHI', 0x111, 0x8003, 0) + b'1-9'.ljust(32, b'\0'))
        self.assertEqual(exact(sock, 8), struct.pack('>HHI', 0x111, 3, 1))


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0]])
