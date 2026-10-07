import os
from pathlib import Path
import sys

os.environ["QT_QPA_PLATFORM"] = "offscreen"
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "linux"))
from app import LauncherWindow
from PySide6.QtWidgets import QApplication

application = QApplication([])
window = LauncherWindow(auto_poll=False, load_media=False)
window.state.update("platform=ready\nengine=ready\nsteam=ready\ninstall=busy\nsteam_session_vanilla=active\nsteam_download_vanilla=waiting-password")
window.show_steam_guide()
application.processEvents()
for status in ("waiting-password", "awaiting-guard", "wrong-password", "validating", "complete"):
    window.state.values["steam_download_vanilla"] = status
    if status == "complete":
        window.state.values["assets"] = "ready"
        window.state.values["install"] = "idle"
        window.state.values.pop("steam_session_vanilla")
    window.refresh_view()
    application.processEvents()
    window.steam_guide.grab().save(str(root / f"dist/steam-guide-{status}.png"))
window.close()
print("Steam guide previews captured with simulated statuses; no network, Steam or games.")
