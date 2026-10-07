import os
from pathlib import Path
import sys
os.environ["QT_QPA_PLATFORM"] = "offscreen"
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / "linux"))
from PySide6.QtWidgets import QApplication
from PySide6.QtCore import Qt
from PySide6.QtGui import QPixmap
from app import LauncherWindow
application = QApplication([])
window = LauncherWindow(resources=root, auto_poll=False, load_media=False)
if os.environ.get("GX_LOGO_PREVIEW_ROOT"):
    for game in window.state.games:
        pixmap = QPixmap(str(Path(os.environ["GX_LOGO_PREVIEW_ROOT"]) / (game["id"] + "-logo.png")))
        if pixmap.isNull():
            raise SystemExit("Missing preview artwork for " + game["id"])
        window.game_logo_labels[game["id"]].setPixmap(pixmap.scaled(172, 70, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation))
window.state.update("platform=ready\nengine=ready\nsteam=ready\nassets=ready\ninstall=idle\nrotr=ready")
window.step = 3
window.refresh_view()
window.show()
application.processEvents()
(root / "dist").mkdir(exist_ok=True)
window.grab().save(str(root / "dist/linux-ui-preview.png"))
for game in window.state.games:
    window.choose_game(game["id"])
    application.processEvents()
    window.grab().save(str(root / f'dist/linux-{game["id"]}-preview.png'))
window.close()
print("Linux offscreen preview captured. No game or sign-in was started.")
