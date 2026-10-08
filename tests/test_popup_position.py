import importlib.machinery
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "home/scripts/.local/bin/waybar-popup"
loader = importlib.machinery.SourceFileLoader("waybar_popup", str(PATH))
spec = importlib.util.spec_from_loader(loader.name, loader)
popup = importlib.util.module_from_spec(spec)
loader.exec_module(popup)


def monitor(name="eDP-1", x=0, y=0, width=2880, height=1800, scale=2, transform=0):
    return dict(name=name, x=x, y=y, width=width, height=height, scale=scale,
                transform=transform, focused=True)


def layers(name="eDP-1", x=0, y=0, height=24):
    return {name: {"levels": {"2": [dict(namespace="waybar", x=x, y=y,
                                        w=1440, h=height)]}}}


class PopupPositionTests(unittest.TestCase):
    def test_scaled_cursor_is_already_in_logical_coordinates(self):
        result = popup.opening_context(dict(x=1400, y=12), [monitor()], layers())
        self.assertEqual(result["width"], 1440)
        self.assertEqual(result["x"], 1400)
        self.assertEqual(result["barBottom"], 24)
        self.assertEqual(result["gap"], 8)

    def test_secondary_monitor_with_negative_origin(self):
        monitors = [monitor(), monitor("DP-1", -1920, -200, 1920, 1080, 1)]
        result = popup.opening_context(dict(x=-50, y=-185), monitors,
                                       layers("DP-1", -1920, -200, 30))
        self.assertEqual(result["monitor"], "DP-1")
        self.assertEqual(result["x"], 1870)
        self.assertEqual(result["barBottom"], 30)

    def test_rotated_fractional_scale(self):
        rotated = monitor("DP-2", 1440, 0, 2560, 1440, 1.25, 1)
        result = popup.opening_context(dict(x=1500, y=12), [rotated], {})
        self.assertEqual(result["width"], 1152)
        self.assertEqual(result["height"], 2048)
        self.assertEqual(result["x"], 60)

    def test_real_waybar_bottom_includes_top_margin(self):
        result = popup.opening_context(dict(x=100, y=20), [monitor()], layers(y=4, height=28))
        self.assertEqual(result["barBottom"], 32)

    def test_disabled_monitor_and_mirror_are_ignored(self):
        disabled = dict(monitor("disabled"), disabled=True)
        mirror = dict(monitor("mirror"), mirrorOf=0)
        result = popup.opening_context(dict(x=20, y=12), [disabled, mirror, monitor()], layers())
        self.assertEqual(result["monitor"], "eDP-1")

    def test_absent_cursor_monitor_returns_empty_context(self):
        self.assertEqual(popup.opening_context(dict(x=9999, y=0), [monitor()], {}), {})

    def test_failed_query_uses_fallback_without_leaking_error(self):
        with patch.object(popup, "query", side_effect=OSError("private diagnostic")):
            self.assertEqual(popup.capture(), {})

    def test_layer_query_failure_preserves_monitor_and_cursor(self):
        with patch.object(popup, "query", side_effect=[dict(x=100, y=12), [monitor()], OSError()]):
            result = popup.capture()
        self.assertEqual(result["monitor"], "eDP-1")
        self.assertEqual(result["x"], 100)
        self.assertEqual(result["barBottom"], 24)

    def test_invalid_geometry_is_rejected(self):
        for scale in (0, -1, float("nan"), True):
            with self.assertRaises(ValueError):
                popup.monitor_geometry(monitor(scale=scale))


if __name__ == "__main__":
    unittest.main()
