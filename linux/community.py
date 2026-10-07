from PySide6.QtCore import Qt
from PySide6.QtWidgets import QDialog, QHBoxLayout, QLabel, QPushButton, QScrollArea, QVBoxLayout, QWidget


class CommunityWindow(QDialog):
    def __init__(self, launcher):
        super().__init__(launcher)
        state = launcher.state
        info, ledger = state.community, state.donations
        self.setWindowTitle(info["title"])
        self.resize(680, 650)
        layout = QVBoxLayout(self)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        body = QWidget()
        contents = QVBoxLayout(body)
        contents.setSpacing(15)

        def text(value, heading=False):
            label = QLabel(value)
            label.setWordWrap(True)
            label.setTextFormat(Qt.TextFormat.PlainText)
            if heading:
                label.setStyleSheet("font-weight:bold; font-size:15px;")
            contents.addWidget(label)
            return label

        def link(label, url):
            button = QPushButton(label.replace("&", "&&"))
            button.clicked.connect(lambda: launcher.open_url(url))
            contents.addWidget(button)

        text(info["mission"], True)
        text(info["credit"])
        text("Supporting the people behind it", True)
        text(info["donationPolicy"])
        link("Support the launcher on Ko-fi", "https://ko-fi.com/ricklemore")
        self.count_label = text(f'{len(ledger["donations"])} onward donations recorded · updated {ledger["lastUpdated"]}', True)
        text(info["ledgerDetail"])
        if not ledger["donations"]:
            text(info["emptyLedger"])
        for donation in ledger["donations"]:
            text(f'{donation["date"]} · {donation["project"]} · {donation["amount"]} {donation["currency"]}')
            if donation.get("evidenceURL"):
                link("Public record", donation["evidenceURL"])
        link("Latest public credits & donation ledger", "https://github.com/" + state.product["repository"] + "/blob/main/docs/community.md")
        text("Engines, mods and tools", True)
        text("Project links include contributors or team pages. Upstream credits also acknowledge their libraries and earlier work.")
        for project in info["projects"]:
            text(project["name"], True)
            text(project["role"])
            row = QHBoxLayout()
            for label, url in (("Project", project["url"]), ("Contributors / team", project["contributorsURL"])):
                button = QPushButton(label)
                button.clicked.connect(lambda checked=False, target=url: launcher.open_url(target))
                row.addWidget(button)
            contents.addLayout(row)
        link("C&C Unix Launcher contributors", "https://github.com/" + state.product["repository"] + "/graphs/contributors")
        scroll.setWidget(body)
        layout.addWidget(scroll)
        close = QPushButton("Done")
        close.clicked.connect(self.accept)
        layout.addWidget(close)
