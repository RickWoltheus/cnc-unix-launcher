import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import tempfile
import time

os.environ["QT_QPA_PLATFORM"] = "offscreen"
REPO = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO / "linux"))
from state import LauncherState
from app import LauncherWindow
from community import CommunityWindow
from security_setup import SecuritySetupWindow
from PySide6.QtWidgets import QApplication, QLineEdit, QPushButton, QLabel
from PySide6.QtCore import Qt


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
        for game in ("cnc", "ra", "ra2", "yuri", "ts"):
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

    def test_wine_closure_releases_play_gate(self):
        self.state.selected_game = "ra2"
        ready = "platform=ready\nsteam=ready\nra2_engine=ready\nra2_assets=ready\ninstall=idle\n"
        self.state.update(ready + "wine_session=running")
        self.assertFalse(self.state.can_enter(3))
        self.state.update(ready + "wine_session=stopping")
        self.assertFalse(self.state.can_enter(3))
        self.state.update(ready + "wine_session=idle")
        self.assertTrue(self.state.can_enter(3))
        self.state.game_running = True
        self.state.update(ready + "wine_session=idle")
        self.assertTrue(self.state.game_running)

    def test_wine_dependency_gate(self):
        self.state.selected_game = "ra2"
        self.state.values["dependencies"] = "ready"
        self.assertFalse(self.state.tools_ready)
        self.state.values["wine_dependencies"] = "ready"
        self.assertTrue(self.state.tools_ready)

    def test_native_mod_has_its_own_asset_gate(self):
        self.state.selected_game = "cnc"
        self.state.selected_profile = "tdhd"
        self.state.update("platform=ready\ncnc_engine=ready\ncnc_assets=ready\nsteam=ready\ninstall=idle")
        self.assertEqual(self.state.profile, "tdhd")
        self.assertTrue(self.state.needs_install)
        self.state.steam_target = "tdhd"
        self.assertFalse(self.state.can_enter(2))
        self.state.values["native_engine_tdhd"] = "ready"
        self.assertTrue(self.state.can_enter(2))
        self.assertFalse(self.state.can_enter(3))
        self.state.values["tdhd"] = "ready"
        self.assertTrue(self.state.can_enter(3))
        self.assertEqual(self.state.steam_profile, "tdhd")

    def test_profile_selection(self):
        self.assertEqual(self.state.profile, "vanilla")
        for mod in self.state.available_mods:
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

    def test_terminal_operations_keep_scan_preference(self):
        with tempfile.TemporaryDirectory() as root:
            with patch("app.ROOT", Path(root)), patch("app.shutil.which", return_value=None):
                self.window.state.scan_downloads = True
                self.window.open_terminal("Fixture", ["steam-login", "combined-arms"])
                self.assertIn("export GX_SCAN_DOWNLOADS=1", (Path(root) / "fixture.sh").read_text())
                self.window.state.scan_downloads = False
                self.window.open_terminal("Fixture", ["security-update"])
                self.assertIn("export GX_SCAN_DOWNLOADS=0", (Path(root) / "fixture.sh").read_text())

    def test_optional_scanner_setup_and_preferences(self):
        self.window.state.scan_downloads = False
        self.window.state.update("platform=ready\ninstall=idle\nscanner=missing\nscan_definitions=missing")
        dialog = SecuritySetupWindow(self.window)
        self.assertFalse(dialog.scan.isEnabled())
        self.assertFalse(dialog.scan_cache.isEnabled())
        self.window.state.update("platform=ready\ninstall=idle\nscanner=ready\nscan_definitions=ready")
        dialog.refresh()
        self.assertTrue(dialog.scan.isEnabled())
        self.assertTrue(dialog.scan_cache.isEnabled())
        dialog.scan.setChecked(True)
        self.assertEqual(self.window.environment().value("GX_SCAN_DOWNLOADS"), "1")
        self.window.state.update("platform=ready\ninstall=idle\nscanner=missing\nscan_definitions=missing")
        dialog.refresh()
        self.assertTrue(dialog.scan.isEnabled())
        dialog.scan.setChecked(False)
        self.assertEqual(self.window.environment().value("GX_SCAN_DOWNLOADS"), "0")
        dialog.close()

    def test_community_maintainer_support_links(self):
        button = self.window.findChild(QPushButton, "support-kofi")
        self.assertIn("community", button.toolTip())
        self.assertLessEqual(self.window.minimumSizeHint().height(), 790)
        opened = []
        self.window.open_url = opened.append
        dialog = CommunityWindow(self.window)
        buttons = dialog.findChildren(QPushButton)
        for support in self.window.state.community["supportLinks"]:
            label = support["project"] + " · " + support["platform"]
            target = next(button for button in buttons if button.text() == label)
            target.click()
            self.assertEqual(opened[-1], support["url"])
        self.assertFalse(any("onward donations" in label.text() for label in dialog.findChildren(QLabel)))
        dialog.close()

    def test_sidebar_selects_classic_theme_and_profile(self):
        self.window.state.update("platform=ready\nsteam=ready\ncnc_engine=ready\ncnc_assets=ready\ninstall=idle")
        self.window.game_buttons["cnc"].click()
        self.assertEqual(self.window.state.profile, "cnc")
        self.assertIn("#b4cb59", self.window.styleSheet())
        self.window.continue_button.click()
        self.assertEqual(self.window.step, 3)
        self.assertTrue(self.window.play_button.isEnabled())
        self.assertFalse(self.window.graphics.isEnabled())
        self.assertFalse(self.window.mod_section.isHidden())
        self.window.game_buttons["ra"].click()
        self.assertEqual(self.window.step, 0)
        self.assertFalse(self.window.play_button.isEnabled())
        self.assertIn("#f06455", self.window.styleSheet())

    def test_steam_guide_updates_without_starting_terminal(self):
        self.window.state.update("platform=ready\nengine=ready\nsteam=ready\ninstall=busy\nsteam_session_vanilla=active\nsteam_download_vanilla=waiting-password")
        self.window.show_steam_guide()
        guide = self.window.steam_guide
        self.assertTrue(guide.isVisible())
        self.assertFalse(guide.isModal())
        self.assertTrue(guide.windowFlags() & Qt.WindowType.WindowStaysOnTopHint)
        self.assertEqual(guide.findChildren(QLineEdit), [])
        self.assertEqual(guide.status_title.text(), "Enter your Steam password")
        self.window.state.values["steam_download_vanilla"] = "awaiting-guard"
        self.window.refresh_view()
        self.assertEqual(guide.status_title.text(), "Complete Steam Guard")
        self.window.state.values["steam_download_vanilla"] = "wrong-password"
        self.window.refresh_view()
        self.assertFalse(guide.retry_button.isEnabled())
        self.window.state.values.pop("steam_session_vanilla")
        self.window.state.values["install"] = "idle"
        self.window.refresh_view()
        self.assertTrue(guide.retry_button.isEnabled())
        self.window.state.values["assets"] = "ready"
        self.window.state.values["steam_download_vanilla"] = "validating"
        self.window.refresh_view()
        self.assertFalse(guide.continue_button.isEnabled())
        self.window.state.values["steam_download_vanilla"] = "complete"
        self.window.refresh_view()
        self.assertTrue(guide.continue_button.isEnabled())
        guide.continue_button.click()
        self.assertEqual(self.window.step, 3)
        self.assertFalse(guide.isVisible())

    def test_steam_handoff_blocks_duplicate_signin(self):
        self.window.state.update("platform=ready\nengine=ready\nsteam=ready\ninstall=idle")
        calls = []
        self.window.open_terminal = lambda title, arguments: calls.append(arguments) or True
        self.window.signin()
        self.window.signin()
        self.assertEqual(calls, [["steam-login", "vanilla"]])
        self.assertFalse(self.window.signin_button.isEnabled())
        self.window.steam_guide.close()
        self.assertTrue(self.window.state.steam_starting)

    def test_native_asset_handoff_uses_correct_steam_profile(self):
        self.window.state.update("platform=ready\ncnc_engine=ready\ncnc_assets=ready\nsteam=ready\ninstall=idle")
        self.window.choose_game("cnc")
        self.window.choose_profile("tdhd")
        self.window.step = 3
        calls = []
        self.window.open_terminal = lambda title, args: calls.append(args) or True
        self.window.read_status = lambda: None
        with tempfile.TemporaryDirectory() as temp:
            script = Path(temp) / "backend.sh"
            script.write_text("#!/bin/bash\necho 'NATIVE_ASSETS_REQUIRED: fixture'\nexit 1\n")
            self.window.backend = script
            self.window.run_actions([("native-mod", "tdhd")])
            deadline = time.monotonic() + 5
            while self.window.worker is not None and time.monotonic() < deadline:
                self.application.processEvents()
                time.sleep(0.01)
            self.assertEqual(calls, [["steam-login", "tdhd"]])
            self.assertEqual(self.window.state.steam_target, "tdhd")
            self.assertTrue(self.window.steam_guide.isVisible())
            self.assertFalse(self.window.play_button.isEnabled())

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
