import unittest

from ads7953_Nboard_NET_gui import FrameParser, discovery_candidates


def data_frame(board: int, sequence: int) -> bytes:
    payload = bytearray()
    for channel in range(16):
        code = board * 100 + channel
        payload.extend((code & 0xFF, (code >> 8) & 0x0F))
    body = bytes([1, board, 32, sequence & 0xFF, sequence >> 8]) + payload
    checksum = 0
    for value in body:
        checksum ^= value
    return b"\xA5\x5A" + body + bytes([checksum])


def end_frame(sequence: int, board_count: int) -> bytes:
    body = bytes([1, 0xFF, board_count, sequence & 0xFF, sequence >> 8])
    checksum = 0
    for value in body:
        checksum ^= value
    return b"\xA5\x5A" + body + bytes([checksum])


class UdpPayloadParserTest(unittest.TestCase):
    def test_discovery_candidates_use_fpga_subnet(self):
        addresses = [
            "192.168.31.211", "192.168.1.10", "198.18.0.1",
            "192.168.1.20", "192.168.1.50"]
        self.assertEqual(
            ["192.168.1.10", "192.168.1.20"],
            discovery_candidates(addresses))

    def test_complete_two_board_udp_payload(self):
        parser = FrameParser()
        payload = data_frame(0, 9) + data_frame(1, 9) + end_frame(9, 2)
        frames = parser.feed(payload)
        self.assertEqual(["data", "data", "end"], [frame[0] for frame in frames])
        self.assertEqual([0, 1, 2], [frame[2] for frame in frames])
        self.assertTrue(all(frame[1] == 9 for frame in frames))


if __name__ == "__main__":
    unittest.main()
