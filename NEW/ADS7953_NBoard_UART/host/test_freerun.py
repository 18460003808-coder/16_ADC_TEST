import queue
import unittest

from ads7953_freerun_gui import FreeRunApp


class StopAfterThreeWaits:
    def __init__(self):
        self.wait_count = 0

    def is_set(self):
        return False

    def wait(self, _timeout):
        self.wait_count += 1
        return self.wait_count == 3


class FakeSerialPort:
    is_open = True

    def __init__(self):
        self.writes = []

    def write(self, value):
        self.writes.append(value)


class FreeRunTest(unittest.TestCase):
    def test_sends_repeatedly_without_received_frames(self):
        app = object.__new__(FreeRunApp)
        app.serial_port = FakeSerialPort()
        app.continuous_stop_event = StopAfterThreeWaits()
        app.events = queue.Queue()

        app._continuous_writer(20, 0)

        self.assertEqual(app.serial_port.writes, [b"T", b"T", b"T"])


if __name__ == "__main__":
    unittest.main()
