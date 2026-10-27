import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from ads7953_Nboard_gui import (
    FrameParser, build_slide_command, configuration_directory,
    create_identity_board_mapping, default_export_directory,
    load_board_mapping, remap_board_group,
)


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
    @staticmethod
    def _mapping_csv(first: int = 1, second: int = 2) -> str:
        rows = ["capture_slot,logical_board", f"1,{first}", f"2,{second}"]
        rows.extend(f"{index},{index}" for index in range(3, 21))
        return "\n".join(rows) + "\n"

    def test_board_mapping_loads_swapped_first_two_boards(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "board_mapping.csv"
            path.write_text(self._mapping_csv(2, 1), encoding="utf-8")
            mapping = load_board_mapping(path)
        self.assertEqual((1, 0), mapping[:2])
        self.assertEqual(tuple(range(2, 20)), mapping[2:])

    def test_macos_paths_and_first_run_mapping(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            home = Path(temporary_directory)
            config_dir = configuration_directory("darwin", home)
            self.assertEqual(
                home / "Library" / "Application Support" /
                "ADS7953_NBoard_UART_SLIDE",
                config_dir)
            mapping_path = config_dir / "board_mapping.csv"
            create_identity_board_mapping(mapping_path)
            self.assertEqual(tuple(range(20)), load_board_mapping(mapping_path))
            self.assertEqual(home, default_export_directory("darwin", home))
            (home / "Documents").mkdir()
            self.assertEqual(
                home / "Documents", default_export_directory("darwin", home))

    def test_board_mapping_rejects_duplicate_logical_board(self) -> None:
        with TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "board_mapping.csv"
            path.write_text(self._mapping_csv(1, 1), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "实际子板1重复配置"):
                load_board_mapping(path)

    def test_remap_board_group_uses_logical_board_ids(self) -> None:
        physical_boards = {
            0: ([0] * 16, False),
            1: ([100] * 16, True),
        }
        mapping = (1, 0) + tuple(range(2, 20))
        logical_boards = remap_board_group(physical_boards, 2, mapping)
        self.assertEqual(([100] * 16, True), logical_boards[0])
        self.assertEqual(([0] * 16, False), logical_boards[1])

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
