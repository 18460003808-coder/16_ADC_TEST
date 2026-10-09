import queue
import unittest

from ads7953_freerun_NET_gui import FreeRunApp


class StopAfterThreeWaits:
    def __init__(self):
        self.wait_count = 0

    def is_set(self):
        return False

    def wait(self, _timeout):
        self.wait_count += 1
        return self.wait_count == 3


class FakeUdpSocket:
    def __init__(self):
        self.sends = []

    def sendto(self, value, target):
        self.sends.append((value, target))


class FakeTargetVar:
    def get(self):
        return "192.168.1.50"


class FreeRunTest(unittest.TestCase):
    def test_sends_repeatedly_without_received_datagrams(self):
        app = object.__new__(FreeRunApp)
        app.udp_socket = FakeUdpSocket()
        app.target_ip_var = FakeTargetVar()
        app.continuous_stop_event = StopAfterThreeWaits()
        app.events = queue.Queue()

        app._continuous_writer(20, 0)

        self.assertEqual(
            app.udp_socket.sends,
            [(b"T", ("192.168.1.50", 5000))] * 3)


if __name__ == "__main__":
    unittest.main()
