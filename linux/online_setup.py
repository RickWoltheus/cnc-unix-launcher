from PySide6.QtWidgets import QCheckBox, QDialog, QLabel, QPushButton, QVBoxLayout


class OnlineSetupWindow(QDialog):
    def __init__(self, launcher):
        super().__init__(launcher)
        self.launcher = launcher
        state = launcher.state
        copy = state.online
        self.setWindowTitle(copy["title"] + " · " + state.title)
        self.setFixedWidth(590)
        self.setModal(True)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(26, 26, 26, 26)
        layout.setSpacing(14)
        openra = state.classic or (state.mod and state.mod["native"])
        family = copy["openra"] if openra else copy["generals"]
        for text in [copy["description"], family["title"], *[f"{index + 1}. {step}" for index, step in enumerate(family["steps"])], family["hosting"]]:
            label = QLabel(text)
            label.setWordWrap(True)
            layout.addWidget(label)
        self.hosting = QCheckBox(copy["hostingLabel"])
        self.hosting.setVisible(bool(openra))
        layout.addWidget(self.hosting)
        button = QPushButton(copy["prepareLabel"])
        button.setEnabled(state.can_enter(3) and not state.needs_install)
        button.clicked.connect(self.prepare)
        layout.addWidget(button)
        note = QLabel(copy["resultNote"])
        note.setWordWrap(True)
        layout.addWidget(note)
        source = QPushButton("Engine multiplayer instructions")
        source.clicked.connect(lambda: launcher.open_url(family["source"]))
        layout.addWidget(source)

    def prepare(self):
        self.launcher.run_actions([("online-prepare", self.launcher.state.profile, "host" if self.hosting.isChecked() else "join")])
        self.close()
