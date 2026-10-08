from PySide6.QtCore import QTimer, QUrl
from PySide6.QtGui import QDesktopServices
from PySide6.QtWidgets import QCheckBox, QDialog, QHBoxLayout, QLabel, QPushButton, QScrollArea, QVBoxLayout, QWidget


class SecuritySetupWindow(QDialog):
    def __init__(self, launcher):
        super().__init__(launcher)
        self.launcher = launcher
        state, copy = launcher.state, launcher.state.security
        self.setWindowTitle(copy["title"])
        self.resize(720, 690)
        layout = QVBoxLayout(self)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        body = QWidget()
        contents = QVBoxLayout(body)
        contents.setSpacing(14)

        def text(value):
            label = QLabel(value)
            label.setWordWrap(True)
            contents.addWidget(label)
            return label

        for key in ("detail", "steam", "mods"):
            text(copy[key])
        self.scan = QCheckBox(copy["scanLabel"])
        self.scan.setChecked(state.scan_downloads)
        self.scan.toggled.connect(self.set_scan)
        contents.addWidget(self.scan)
        for key in ("scanDetail", "privacy", "limits"):
            text(copy[key])
        self.status = text("")
        row = QHBoxLayout()
        self.install = QPushButton(copy["installLabel"])
        self.install.clicked.connect(lambda: launcher.open_terminal("Optional scanner installation", ["security-tools"]))
        self.update = QPushButton(copy["updateLabel"])
        self.update.clicked.connect(lambda: launcher.open_terminal("Virus definition update", ["security-update"]))
        refresh = QPushButton("Refresh")
        refresh.clicked.connect(launcher.read_status)
        for button in (self.install, self.update, refresh):
            row.addWidget(button)
        contents.addLayout(row)
        text(copy["setupDetail"])
        self.scan_cache = QPushButton(copy["scanCacheLabel"])
        self.scan_cache.clicked.connect(lambda: launcher.run_actions([("security-scan-cache", state.selected_game)]))
        contents.addWidget(self.scan_cache)
        reports = QPushButton("Open local reports")
        reports.clicked.connect(lambda: QDesktopServices.openUrl(QUrl.fromLocalFile(str(launcher.install_root / "security"))))
        contents.addWidget(reports)
        for title, url in (("ClamAV official downloads", copy["scannerURL"]), ("Scanner limits", copy["docsURL"]), ("Sources and security review", "https://github.com/" + state.product["repository"] + "/blob/main/docs/security.md")):
            button = QPushButton(title)
            button.clicked.connect(lambda checked=False, target=url: launcher.open_url(target))
            contents.addWidget(button)
        scroll.setWidget(body)
        layout.addWidget(scroll)
        close = QPushButton("Done")
        close.clicked.connect(self.accept)
        layout.addWidget(close)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh)
        self.timer.start(1000)
        self.refresh()

    def set_scan(self, value):
        self.launcher.state.scan_downloads = value
        self.launcher.settings.setValue("scanDownloads", value)

    def refresh(self):
        state = self.launcher.state
        locked = state.busy or state.game_running or state.values.get("install") == "busy"
        available = state.values.get("scanner") == "ready"
        ready = state.values.get("scan_definitions") == "ready"
        self.scan.setEnabled(not locked and (state.scan_downloads or (available and ready)))
        self.install.setEnabled(not locked)
        self.update.setEnabled(not locked and available)
        self.scan_cache.setEnabled(not locked and available and ready)
        self.status.setText("ClamAV: " + ("installed" if available else "not found") + " · Definitions: " + state.values.get("scan_definitions", "missing"))

    def closeEvent(self, event):
        self.timer.stop()
        super().closeEvent(event)
