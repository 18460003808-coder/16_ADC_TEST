import unittest

from ads7953_Nboard_gui import FrameParser, build_slide_command


def xor(data: bytes) -> int:
    value = 0
    for byte in data:
        value ^= byte
    return value


def data_frame(sequence: int, board: int) -> bytes:
    body = bytearray([1, board, 32, sequence & 0xFF, sequence >> 8])
    for channel in range(16):
        code = board * 0x100 + channel
        body.extend((code & 0xFF, (code >> 8) & 0x0F))
    return b"\xA5\x5A" + body + bytes([xor(body)])


def end_frame(sequence: int, board_count: int) -> bytes:
    body = bytes([1, 0xFF, board_count, sequence & 0xFF, sequence >> 8])
    return b"\xA5\x5A" + body + bytes([xor(body)])


def slide_done_frame(direction: int, pulse_count: int) -> bytes:
    body = bytes([
        1, 0xFE, 1, direction, pulse_count & 0xFF, pulse_count >> 8,
    ])
    return b"\xA5\x5A" + body + bytes([xor(body)])


class FrameParserTest(unittest.TestCase):
    def test_slide_command(self) -> None:
        command = build_slide_command(1, 80)
        self.assertEqual(b"\x55\xAA\x4D\x01\x50\x00\x1C", command)

    def test_fragmented_slide_done_between_adc_groups(self) -> None:
        stream = data_frame(3, 0) + end_frame(3, 1)
        stream += slide_done_frame(1, 160)
        parser = FrameParser()
        result = []
        for index in range(0, len(stream), 7):
            result.extend(parser.feed(stream[index:index + 7]))
        self.assertEqual([item[0] for item in result], ["data", "end", "slide"])
        self.assertEqual((1, [160]), (result[-1][2], result[-1][3]))

    def test_bad_slide_checksum_is_rejected(self) -> None:
        bad = bytearray(slide_done_frame(0, 40))
        bad[-1] ^= 0x01
        self.assertEqual([], FrameParser().feed(bytes(bad)))

    def test_fragmented_n_board_group(self) -> None:
        stream = b"noise" + b"".join(data_frame(7, board) for board in range(3))
        stream += end_frame(7, 3)
        parser = FrameParser()
        result = []
        for index in range(0, len(stream), 11):
            result.extend(parser.feed(stream[index:index + 11]))
        self.assertEqual([item[0] for item in result], ["data"] * 3 + ["end"])
        self.assertEqual([item[2] for item in result], [0, 1, 2, 3])
        self.assertEqual({item[1] for item in result}, {7})
        self.assertFalse(any(item[4] for item in result))


if __name__ == "__main__":
    unittest.main()
