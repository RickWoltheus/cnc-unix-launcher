from PySide6.QtCore import Qt
from PySide6.QtWidgets import QDialog, QHBoxLayout, QLabel, QPushButton, QVBoxLayout


class SteamGuideWindow(QDialog):
    def __init__(self, launcher):
        super().__init__(launcher, Qt.WindowType.Window | Qt.WindowType.WindowStaysOnTopHint)
        self.launcher = launcher
        self.copy = launcher.state.guide_copy
        self.setWindowTitle(self.copy["title"])
        self.setModal(False)
        self.setAttribute(Qt.WidgetAttribute.WA_ShowWithoutActivating)
        self.setFixedWidth(420)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(22, 22, 22, 22)
        layout.setSpacing(16)
        title = QLabel(self.copy["title"])
        title.setStyleSheet("font-size:20px; font-weight:bold;")
        layout.addWidget(title)
        self.game_title = QLabel("")
        layout.addWidget(self.game_title)
        security_title = QLabel(self.copy["securityTitle"])
        security_title.setStyleSheet("font-weight:bold;")
        layout.addWidget(security_title)
        security = QLabel(self.copy["securityDetail"])
        security.setWordWrap(True)
        layout.addWidget(security)
        steps = QHBoxLayout()
        self.steps = []
        for name in self.copy["stages"]:
            label = QLabel(name)
            label.setWordWrap(True)
            steps.addWidget(label, 1)
            self.steps.append(label)
        layout.addLayout(steps)
        self.status_title = QLabel("")
        self.status_title.setWordWrap(True)
        self.status_title.setObjectName("steam-guide-status")
        layout.addWidget(self.status_title)
        self.status_detail = QLabel("")
        self.status_detail.setWordWrap(True)
        layout.addWidget(self.status_detail)
        self.progress_note = QLabel(self.copy["visibilityDetail"] + " Switch to the Steam terminal through your desktop’s taskbar to type.")
        self.progress_note.setWordWrap(True)
        layout.addWidget(self.progress_note)
        self.retry_button = QPushButton(self.copy["retryLabel"])
        self.retry_button.clicked.connect(launcher.signin)
        layout.addWidget(self.retry_button)
        self.continue_button = QPushButton(self.copy["continueLabel"])
        self.continue_button.clicked.connect(self.continue_to_play)
        layout.addWidget(self.continue_button)
        help_button = QPushButton(self.copy["helpLabel"])
        help_button.clicked.connect(lambda: launcher.open_url("https://help.steampowered.com/en/wizard/HelpWithLogin"))
        layout.addWidget(help_button)
        self.refresh()

    def refresh(self):
        state = self.launcher.state
        status = "complete" if state.assets_ready else "waiting" if state.steam_starting else state.steam_status
        guidance = state.guidance.get(status, state.guidance["idle"])
        accent = "#" + state.game["accent"]
        self.game_title.setText(state.game["title"])
        error = self.launcher.steam_launch_error
        self.status_title.setText("Steam terminal could not open" if error else guidance["title"])
        self.status_title.setStyleSheet(f"color:{accent}; font-size:16px; font-weight:bold;")
        self.status_detail.setText(error or guidance["detail"])
        for index, label in enumerate(self.steps):
            done = state.assets_ready or index < guidance["stage"]
            label.setText(("✓  " if done else str(index + 1) + "  ") + self.copy["stages"][index])
            label.setStyleSheet(f"color:{accent};" if done or index == guidance["stage"] else "color:#a4b0b3;")
        self.retry_button.setVisible(guidance["error"] or error is not None)
        self.retry_button.setEnabled(state.can_enter(2) and not state.steam_active and not state.steam_starting and state.values.get("install") != "busy")
        self.continue_button.setVisible(state.assets_ready)
        self.continue_button.setEnabled(state.can_enter(3))
        self.adjustSize()

    def continue_to_play(self):
        if not self.launcher.state.can_enter(3):
            return
        self.launcher.go_to(3)
        self.close()
        self.launcher.showNormal()
        self.launcher.raise_()
        self.launcher.activateWindow()
