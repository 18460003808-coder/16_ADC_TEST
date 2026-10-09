"""ADS7953 fixed-period trigger UI; sending never waits for an FPGA reply."""

import tkinter as tk

from ads7953_Nboard_gui import Ads7953App


class FreeRunApp(Ads7953App):
    def __init__(self, root: tk.Tk) -> None:
        super().__init__(root)
        self.root.title("ADS7953 N板串口连续触发工具（不等待反馈）")
        self.interval_var.set("100")
        self.duration_var.set("0")
        self.continuous_button.configure(text="开始连续触发（不等待反馈）")
        self.status.set("连接串口后，按固定周期持续发送T；接收与显示独立运行")

    def _toggle_continuous(self) -> None:
        super()._toggle_continuous()
        if self.continuous_active:
            self.continuous_button.configure(text="停止连续触发")
            self.status.set(
                f"连续触发中：每 {self.interval_var.get()} ms发送T，不等待FPGA反馈")

    def _stop_continuous(self, update_status: bool = True) -> None:
        super()._stop_continuous(update_status)
        if hasattr(self, "continuous_button"):
            self.continuous_button.configure(text="开始连续触发（不等待反馈）")


def main() -> None:
    root = tk.Tk()
    FreeRunApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()
