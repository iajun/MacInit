# manim -pql scenes/01_example.py ExampleHook
# MANIM_FORMAT=portrait manim -pql scenes/01_example.py ExampleHook -r 1080,1920
"""Example scene — delete after real Scene 01 exists."""

from manim import *

from scenes.shared.layout import frame_for, place_hero, stack_vertical
from scenes.shared.palette import C


class ExampleHook(Scene):
    def construct(self):
        fmt = frame_for()
        self.camera.background_color = C.BG

        q = Text("本集只回答一个问题", font_size=36, color=C.MUTED)
        hero = Text("误差，到底怎么改参数？", font_size=48 if fmt == "landscape" else 40, color=C.TEXT)
        group = stack_vertical(q, hero, buff=0.5)
        place_hero(group, fmt)

        self.play(FadeIn(q, shift=UP * 0.2), run_time=0.6)
        self.play(Write(hero), run_time=1.2)
        self.wait(1.2)

        knob = Circle(radius=0.55, color=C.PARAM, stroke_width=6)
        label = Text("旋钮 = 参数", font_size=28, color=C.PARAM).next_to(knob, DOWN)
        demo = stack_vertical(knob, label, buff=0.3)
        if fmt == "portrait":
            demo.next_to(group, DOWN, buff=0.8)
        else:
            demo.next_to(group, DOWN, buff=0.9)

        self.play(Create(knob), FadeIn(label), run_time=0.8)
        self.play(Rotate(knob, angle=0.6), run_time=0.8)
        self.wait(1.0)
