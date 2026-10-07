import os
from pathlib import Path
import sys
import unittest

os.environ["QT_QPA_PLATFORM"] = "offscreen"
REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "linux"))
from state import LauncherState
from app import LauncherWindow
from PySide6.QtWidgets import QApplication


class StateChecks(unittest.TestCase):
    def setUp(self):
        self.state = LauncherState(REPO)
        self.state.update("platform=ready\ninstall=idle")

    def test_step_prerequisites(self):
        self.assertTrue(self.state.can_enter(1))
        self.assertFalse(self.state.can_enter(2))
        self.assertFalse(self.state.can_enter(3))
        self.state.update("platform=ready\nengine=ready\nsteam=ready\ninstall=idle")
        self.assertTrue(self.state.can_enter(2))
        self.assertFalse(self.state.can_enter(3))
        self.state.values["assets"] = "ready"
        self.assertTrue(self.state.can_enter(3))
        for status in ("waiting", "awaiting-guard", "wrong-password", "no-license", "downloading"):
            self.state.values["steam_download_vanilla"] = status
            self.assertFalse(self.state.can_enter(3))
        self.state.values["steam_download_vanilla"] = "complete"
        self.assertTrue(self.state.can_enter(3))
        self.state.values["steam_session_vanilla"] = "active"
        self.assertFalse(self.state.can_enter(3))

    def test_classic_game_readiness_is_independent(self):
        for game in ("cnc", "ra"):
            self.state.selected_game = game
            self.state.update("platform=ready\nengine=ready\nsteam=ready\nassets=ready\ninstall=idle")
            self.assertEqual(self.state.profile, game)
            self.assertIsNone(self.state.mod)
            self.assertFalse(self.state.can_enter(2))
            self.state.values[game + "_engine"] = "ready"
            self.assertTrue(self.state.can_enter(2))
            self.assertFalse(self.state.can_enter(3))
            self.state.values[game + "_assets"] = "ready"
            self.assertTrue(self.state.can_enter(3))

    def test_profile_selection(self):
        self.assertEqual(self.state.profile, "vanilla")
        for mod in self.state.mods:
            self.state.selected_profile = mod["id"]
            self.assertEqual(self.state.profile, mod["id"])
            self.assertTrue(self.state.needs_install)
            self.state.values[mod["id"]] = "ready"
            self.assertFalse(self.state.needs_install)
        self.state.selected_game = "base"
        self.assertEqual(self.state.profile, "base")
        self.assertIsNone(self.state.mod)
        self.assertFalse(self.state.needs_install)

    def test_game_switch_requires_its_own_install(self):
        self.state.update("platform=ready\nengine=ready\nsteam=ready\nassets=ready\ninstall=idle")
        self.assertTrue(self.state.can_enter(3))
        self.state.selected_game = "base"
        self.assertFalse(self.state.can_enter(2))
        self.state.values["base_engine"] = "ready"
        self.assertTrue(self.state.can_enter(2))
        self.assertFalse(self.state.can_enter(3))
        self.state.values["base_assets"] = "ready"
        self.assertTrue(self.state.can_enter(3))

    def test_shared_steam_guidance(self):
        self.state.values["steam_download_vanilla"] = "wrong-password"
        self.assertEqual(self.state.steam_guidance["title"], "Steam rejected the password")
        self.state.values["steam_download_vanilla"] = "no-license"
        self.assertEqual(self.state.steam_guidance["title"], "This Steam account does not own the game")
        self.assertEqual(self.state.recovery_for("Checksum mismatch")["title"], "The download did not match")


class WidgetChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.application = QApplication.instance() or QApplication([])

    def setUp(self):
        self.window = LauncherWindow(resources=REPO, auto_poll=False, load_media=False)

    def tearDown(self):
        self.window.state.game_running = False
        self.window.state.busy = False
        self.window.close()
        self.window.deleteLater()
        self.application.processEvents()

    def test_fresh_ui_locks_later_steps(self):
        self.window.state.update("platform=ready\ninstall=idle")
        self.window.refresh_view()
        self.assertTrue(self.window.continue_button.isEnabled())
        self.assertFalse(self.window.step_buttons[2].isEnabled())
        self.assertFalse(self.window.step_buttons[3].isEnabled())
        self.window.go_to(3)
        self.assertEqual(self.window.step, 0)

    def test_single_play_action_uses_selected_mod(self):
        self.window.state.update("platform=ready\nengine=ready\nsteam=ready\nassets=ready\ninstall=idle\nrotr=ready")
        self.window.step = 3
        calls = []
        self.window.start_game = lambda: calls.append(self.window.state.profile)
        self.window.choose_profile("rotr")
        self.assertEqual(self.window.play_title.text(), "RISE OF THE REDS")
        self.window.play_button.click()
        self.assertEqual(calls, ["rotr"])
        self.window.choose_profile("vanilla")
        self.window.play_button.click()
        self.assertEqual(calls, ["rotr", "vanilla"])
        self.window.choose_profile("shockwave")
        self.assertEqual(self.window.play_button.text(), "INSTALL & PLAY →")

    def test_sidebar_selects_classic_theme_and_profile(self):
        self.window.state.update("platform=ready\nsteam=ready\ncnc_engine=ready\ncnc_assets=ready\ninstall=idle")
        self.window.game_buttons["cnc"].click()
        self.assertEqual(self.window.state.profile, "cnc")
        self.assertIn("#b4cb59", self.window.styleSheet())
        self.window.continue_button.click()
        self.assertEqual(self.window.step, 3)
        self.assertTrue(self.window.play_button.isEnabled())
        self.assertFalse(self.window.graphics.isEnabled())
        self.assertTrue(self.window.mod_section.isHidden())
        self.window.game_buttons["ra"].click()
        self.assertEqual(self.window.step, 0)
        self.assertFalse(self.window.play_button.isEnabled())
        self.assertIn("#f06455", self.window.styleSheet())

    def test_download_and_game_running_disable_controls(self):
        self.window.state.update("platform=ready\nengine=ready\nsteam=ready\nassets=ready\ninstall=busy\nsteam_session_vanilla=active\nsteam_download_vanilla=waiting-password")
        self.window.step = 2
        self.window.refresh_view()
        self.assertFalse(self.window.signin_button.isEnabled())
        self.assertFalse(self.window.play_button.isEnabled())
        self.assertEqual(self.window.steam_help_title.text(), "Enter your Steam password")
        self.window.state.game_running = True
        self.window.refresh_view()
        self.assertFalse(self.window.graphics.isEnabled())


if __name__ == "__main__":
    unittest.main()
