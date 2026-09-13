"""Shared color roles — bind semantics, don't scatter hex in scenes."""

from manim import ManimColor

class C:
    BG = ManimColor("#0E1116")
    TEXT = ManimColor("#F2F0EA")
    MUTED = ManimColor("#8B8A85")
    PARAM = ManimColor("#6FA8FF")      # 参数 / 旋钮
    LOSS = ManimColor("#FF6B5A")       # 损失 / 误差
    UPDATE = ManimColor("#F5C542")     # 更新方向
    OK = ManimColor("#7DDA8A")         # 接近目标
    ACCENT = ManimColor("#E8DCC8")     # 金句 / 强调字
