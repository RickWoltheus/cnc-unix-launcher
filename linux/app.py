import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
from urllib.parse import urlencode

from PySide6.QtCore import QProcess, QProcessEnvironment, QSettings, QTimer, QUrl, Qt
from PySide6.QtGui import QColor, QDesktopServices, QFont, QIcon, QPixmap
from PySide6.QtNetwork import QNetworkAccessManager, QNetworkRequest
from PySide6.QtWidgets import QApplication, QCheckBox, QComboBox, QFrame, QHBoxLayout, QLabel, QMainWindow, QMessageBox, QProgressBar, QPushButton, QScrollArea, QStackedWidget, QTextEdit, QVBoxLayout, QWidget
from state import LauncherState
from steam_guide import SteamGuideWindow
from online_setup import OnlineSetupWindow
from community import CommunityWindow
from security_setup import SecuritySetupWindow

ROOT = Path(os.environ.get("GX_INSTALL_ROOT", str(Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share"))) / "generalsx-launcher")))
RESOURCES = Path(sys._MEIPASS) / "share" if getattr(sys, "frozen", False) else Path(__file__).resolve().parents[1]

STYLE = """
QWidget { background:#101619; color:#ecedeb; font-family:DejaVu Sans; font-size:13px; }
QLabel { background:transparent; }
QFrame#library { background:#0b1013; }
QFrame#panel { background:#1a2226; border:1px solid #30393b; border-radius:5px; }
QPushButton { background:#1c2529; color:#d7dddd; border:1px solid #354044; padding:12px 16px; border-radius:3px; }
QPushButton:hover { border-color:#efad40; }
QPushButton:disabled { color:#697478; border-color:#263034; }
QPushButton#primary { background:#efad40; color:#111719; font-weight:bold; padding:16px 25px; }
QPushButton#primary:disabled { background:#635334; color:#a29a89; }
QLabel#eyebrow { color:#efad40; font-weight:bold; }
QPushButton#support-kofi { background:#efad40; color:#111719; font-size:14px; font-weight:bold; padding:12px 18px; border-radius:8px; }
QPushButton#selected { border:2px solid #efad40; color:#efad40; }
QPushButton#step { background:transparent; border:none; padding:12px; }
QPushButton#step:checked { color:#efad40; }
QComboBox { background:#232c30; padding:6px; border:1px solid #354044; }
QCheckBox { padding:6px; }
QTextEdit { background:#151e22; color:#aab8b9; border:1px solid #354044; }
QScrollArea { border:none; }
QProgressBar { border:1px solid #354044; max-height:8px; }
QProgressBar::chunk { background:#efad40; }
"""


class LauncherWindow(QMainWindow):
    def __init__(self, resources=RESOURCES, auto_poll=True, load_media=True):
        super().__init__()
        self.install_root = ROOT
        self.resources = resources
        self.backend = resources / "scripts/backend.sh"
        self.state = LauncherState(resources)
        self.step = 0
        self.queue = []
        self.worker = None
        self.status_worker = None
        self.play_after_install = False
        self.play_after_steam = False
        self.waiting_dependencies = False
        self.steam_start_deadline = None
        self.steam_launch_error = None
        self.steam_guide = None
        self.output = ""
        self.image_labels = {}
        self.update_url = None
        self.media_loaded = False
        self.load_media = load_media
        self.settings = QSettings("GeneralsXLauncher", "Linux")
        self.state.scan_downloads = self.settings.value("scanDownloads", False, type=bool)
        self.network = QNetworkAccessManager(self)
        self.setWindowTitle(self.state.product["name"])
        self.setWindowIcon(QIcon(str(resources / "resources/launcher-icon.png")))
        self.resize(1200, 790)
        self.setStyleSheet(STYLE)
        container = QWidget()
        self.setCentralWidget(container)
        collection = QHBoxLayout(container)
        collection.setContentsMargins(0, 0, 0, 0)
        collection.setSpacing(0)
        sidebar = QFrame()
        sidebar.setFixedWidth(230)
        sidebar.setObjectName("library")
        library = QVBoxLayout(sidebar)
        library.setContentsMargins(18, 28, 18, 20)
        library.setSpacing(12)
        library.addWidget(QLabel("YOUR COLLECTION"))
        self.game_scroll = QScrollArea()
        self.game_scroll.setWidgetResizable(True)
        self.game_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        game_list = QWidget()
        game_layout = QVBoxLayout(game_list)
        game_layout.setContentsMargins(0, 0, 0, 0)
        game_layout.setSpacing(12)
        self.game_scroll.setWidget(game_list)
        library.addWidget(self.game_scroll, 1)
        self.game_buttons = {}
        self.game_logo_labels = {}
        self.game_logo_pixmaps = {}
        for game in self.state.games:
            button = QPushButton()
            button.setMinimumHeight(116)
            row = QVBoxLayout(button)
            row.setContentsMargins(10, 8, 10, 8)
            row.setSpacing(3)
            logo = QLabel(game["emblem"])
            logo.setFixedSize(172, 70)
            logo.setAlignment(Qt.AlignmentFlag.AlignCenter)
            logo.setStyleSheet(f'color:#{game["accent"]}; font-size:28px; font-weight:bold;')
            logo.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
            logo.setAccessibleName(game["title"])
            self.game_logo_labels[game["id"]] = logo
            row.addWidget(logo, 0, Qt.AlignmentFlag.AlignCenter)
            caption = QLabel(game["title"] + " · " + game["engine"])
            caption.setAlignment(Qt.AlignmentFlag.AlignCenter)
            caption.setWordWrap(True)
            caption.setStyleSheet("font-size:10px;")
            caption.setAttribute(Qt.WidgetAttribute.WA_TransparentForMouseEvents)
            row.addWidget(caption)
            button.clicked.connect(lambda checked=False, id=game["id"]: self.choose_game(id))
            self.game_buttons[game["id"]] = button
            game_layout.addWidget(button)
        game_layout.addStretch()
        issues_button = QPushButton("Bugs && feature requests")
        issues_button.setObjectName("github-issues")
        issues_button.clicked.connect(lambda: self.open_url("https://github.com/" + self.state.product["repository"] + "/issues"))
        library.addWidget(issues_button)
        request_button = QPushButton("Request a mod")
        request_button.setObjectName("request-mod")
        request_button.clicked.connect(self.request_mod)
        library.addWidget(request_button)
        self.community_button = QPushButton("Community && support")
        self.community_button.setObjectName("community-support")
        self.community_button.clicked.connect(self.show_community)
        library.addWidget(self.community_button)
        support_button = QPushButton("☕  Buy me a coffee")
        support_button.setObjectName("support-kofi")
        support_button.setToolTip(self.state.community["tooltip"])
        support_button.clicked.connect(lambda: self.open_url("https://ko-fi.com/ricklemore"))
        library.addWidget(support_button)
        collection.addWidget(sidebar)
        main = QWidget()
        collection.addWidget(main, 1)
        layout = QVBoxLayout(main)
        layout.setContentsMargins(32, 24, 32, 18)
        layout.setSpacing(18)
        header = QHBoxLayout()
        wordmark = QLabel("◈  " + self.state.product["name"].upper())
        font = QFont("DejaVu Sans", 23, QFont.Weight.Black)
        font.setLetterSpacing(QFont.SpacingType.AbsoluteSpacing, 3)
        wordmark.setFont(font)
        wordmark.setStyleSheet("font-size:24px; font-weight:900;")
        header.addWidget(wordmark)
        header.addStretch()
        header.addWidget(QLabel("LINUX COMMAND CENTER · x86_64"))
        layout.addLayout(header)
        steps = QHBoxLayout()
        self.step_buttons = []
        for index, title in enumerate(("Choose game", "Prepare Linux", "Steam download", "Play")):
            button = QPushButton(f"{index + 1}  {title.upper()}")
            button.setObjectName("step")
            button.setCheckable(True)
            button.clicked.connect(lambda checked=False, i=index: self.go_to(i))
            self.step_buttons.append(button)
            steps.addWidget(button)
        layout.addLayout(steps)
        self.pages = QStackedWidget()
        layout.addWidget(self.pages, 1)
        self.make_choose()
        self.make_prepare()
        self.make_steam()
        self.make_play()
        self.notice = QLabel("")
        self.notice.setWordWrap(True)
        self.notice.setStyleSheet("color:#efad40;")
        layout.addWidget(self.notice)
        self.progress = QProgressBar()
        self.progress.setRange(0, 0)
        self.progress.hide()
        layout.addWidget(self.progress)
        self.details = QTextEdit()
        self.details.setReadOnly(True)
        self.details.setMaximumHeight(110)
        self.details.hide()
        layout.addWidget(self.details)
        footer = QHBoxLayout()
        help_menu = QComboBox()
        help_menu.addItems(["Help…", "Repair game engine", "Check Steam files", "Repair selected mod", "Open installation folder", "Steam account help", "Show Steam guide", "Online setup", "Security & downloads"])
        help_menu.activated.connect(self.help_action)
        self.help_menu = help_menu
        footer.addWidget(help_menu)
        detail_button = QPushButton("Details")
        detail_button.clicked.connect(lambda: self.details.setVisible(not self.details.isVisible()))
        footer.addWidget(detail_button)
        footer.addStretch()
        self.update_label = QLabel("Reviewed engine and mod versions")
        footer.addWidget(self.update_label)
        self.update_link = QPushButton("Download update")
        self.update_link.clicked.connect(lambda: self.open_url(self.update_url) if self.update_url else None)
        self.update_link.hide()
        footer.addWidget(self.update_link)
        update_button = QPushButton("Check updates")
        update_button.clicked.connect(self.check_updates)
        footer.addWidget(update_button)
        layout.addLayout(footer)
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.read_status)
        if auto_poll:
            self.timer.start(2500)
            QTimer.singleShot(0, self.read_status)
        self.refresh_view()
        if load_media:
            self.fetch_game_logos()

    def page(self):
        body = QWidget()
        layout = QVBoxLayout(body)
        layout.setContentsMargins(0, 15, 0, 15)
        layout.setSpacing(18)
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setWidget(body)
        self.pages.addWidget(scroll)
        return layout

    def title(self, layout, eyebrow, heading, description):
        kicker = QLabel(eyebrow.upper())
        kicker.setObjectName("eyebrow")
        layout.addWidget(kicker)
        headline = QLabel(heading)
        headline.setFont(QFont("DejaVu Sans", 28, QFont.Weight.Black))
        headline.setStyleSheet("font-size:36px; font-weight:900;")
        layout.addWidget(headline)
        copy = QLabel(description)
        copy.setWordWrap(True)
        copy.setStyleSheet("color:#a4b0b3;")
        layout.addWidget(copy)
        return headline, copy

    def primary(self, text, handler):
        button = QPushButton(text)
        button.setObjectName("primary")
        button.clicked.connect(handler)
        return button

    def make_choose(self):
        layout = self.page()
        self.choose_title, self.choose_summary = self.title(layout, "Your collection", "", "")
        self.choose_engine_panel = QFrame()
        panel = QHBoxLayout(self.choose_engine_panel)
        panel.setContentsMargins(24, 20, 24, 20)
        panel.setSpacing(24)
        self.choose_logo = QLabel("")
        self.choose_logo.setFixedSize(200, 110)
        self.choose_logo.setAlignment(Qt.AlignmentFlag.AlignCenter)
        panel.addWidget(self.choose_logo)
        self.choose_engine = QLabel("")
        self.choose_engine.setWordWrap(True)
        panel.addWidget(self.choose_engine, 1)
        layout.addWidget(self.choose_engine_panel)
        self.choose_note = QLabel("")
        self.choose_note.setWordWrap(True)
        layout.addWidget(self.choose_note)
        self.continue_button = self.primary("CONTINUE →", self.continue_setup)
        layout.addWidget(self.continue_button)
        layout.addStretch()

    def make_prepare(self):
        layout = self.page()
        self.title(layout, "Step 2", "We’ll handle the setup.", "We install your selected engine or free Wine runtime and Steam downloader. No Windows VM or paid compatibility layer.")
        self.engine_row = QLabel("")
        self.steam_row = QLabel("")
        for row in (self.engine_row, self.steam_row):
            row.setMargin(22)
            row.setStyleSheet("background:#1a2226; border:1px solid #30393b;")
            layout.addWidget(row)
        self.prepare_button = self.primary("PREPARE MY LINUX DESKTOP →", self.prepare)
        layout.addWidget(self.prepare_button)
        self.sage_steam_button = QPushButton("OPEN STEAM SETUP →")
        self.sage_steam_button.clicked.connect(lambda: self.run_actions([("sage-steam", self.state.selected_game)]))
        layout.addWidget(self.sage_steam_button)
        note = QLabel("If Linux tools are missing, a terminal opens to install Flatpak and Valve’s 32-bit support. Your distribution may ask for your administrator password there.")
        note.setWordWrap(True)
        layout.addWidget(note)
        layout.addStretch()

    def make_steam(self):
        layout = self.page()
        self.title(layout, "Step 3", "Bring your Steam copy.", "One local sign-in, then Steam downloads and checks your owned files.")
        self.steam_instruction_labels = []
        for text in ["1  Sign in locally with your Steam account login name, not your display name.", "2  Enter your password and newest Steam Guard code only in the Steam terminal.", "3  Keep it open until the download finishes. Play unlocks after validation."]:
            label = QLabel(text)
            label.setWordWrap(True)
            label.setMargin(12)
            layout.addWidget(label)
            self.steam_instruction_labels.append(label)
        self.signin_button = self.primary("SIGN IN TO STEAM →", self.signin)
        layout.addWidget(self.signin_button)
        self.steam_guide_button = QPushButton(self.state.guide_copy["showLabel"])
        self.steam_guide_button.clicked.connect(self.show_steam_guide)
        layout.addWidget(self.steam_guide_button)
        self.steam_security_note = QLabel(self.state.guide_copy["securityDetail"])
        self.steam_security_note.setWordWrap(True)
        layout.addWidget(self.steam_security_note)
        self.steam_help_title = QLabel("")
        self.steam_help_title.setStyleSheet("color:#efad40; font-weight:bold;")
        layout.addWidget(self.steam_help_title)
        self.steam_help_detail = QLabel("")
        self.steam_help_detail.setWordWrap(True)
        layout.addWidget(self.steam_help_detail)
        account_help = QPushButton("Recover your Steam account or password")
        account_help.clicked.connect(lambda: self.open_url("https://help.steampowered.com/en/wizard/HelpWithLogin"))
        layout.addWidget(account_help)
        layout.addStretch()

    def make_play(self):
        layout = self.page()
        self.play_title, self.play_summary = self.title(layout, "Ready to deploy", "ZERO HOUR", "Your game is ready. Select what to play.")
        self.play_button = self.primary("PLAY →", self.play)
        layout.addWidget(self.play_button)
        choices = QHBoxLayout()
        self.fullscreen = QCheckBox("Fullscreen")
        self.fullscreen.setChecked(self.settings.value("fullscreen", True, type=bool))
        self.fullscreen.toggled.connect(lambda value: self.settings.setValue("fullscreen", value))
        choices.addWidget(self.fullscreen)
        self.graphics_label = QLabel("Graphics")
        choices.addWidget(self.graphics_label)
        self.graphics = QComboBox()
        self.graphics.addItems(["Balanced", "Maximum"])
        self.graphics.setCurrentIndex(self.settings.value("maximumGraphics", 0, type=int))
        self.graphics.currentIndexChanged.connect(lambda value: self.settings.setValue("maximumGraphics", value))
        choices.addWidget(self.graphics)
        choices.addStretch()
        online = QPushButton("Online setup")
        online.clicked.connect(self.show_online_setup)
        choices.addWidget(online)
        another = QPushButton("Set up another game")
        another.clicked.connect(lambda: self.go_to(0))
        choices.addWidget(another)
        layout.addLayout(choices)
        self.mod_section = QWidget()
        mods = QVBoxLayout(self.mod_section)
        mods.setContentsMargins(0, 10, 0, 0)
        mods.addWidget(QLabel("CHOOSE WHAT TO PLAY"))
        cards = QHBoxLayout()
        cards.setSpacing(10)
        self.profile_buttons = {}
        self.profile_panels = {}
        for mod in [{"id": "original", "title": "Original game"}] + self.state.mods:
            panel = QFrame()
            panel.setObjectName("panel")
            body = QVBoxLayout(panel)
            image = QLabel("◈")
            image.setAlignment(Qt.AlignmentFlag.AlignCenter)
            image.setFixedHeight(90)
            body.addWidget(image)
            button = QPushButton(mod["title"])
            button.clicked.connect(lambda checked=False, profile=mod["id"]: self.choose_profile(profile))
            self.profile_buttons[mod["id"]] = button
            self.profile_panels[mod["id"]] = panel
            self.image_labels[mod["id"]] = image
            body.addWidget(button)
            cards.addWidget(panel)
        mods.addLayout(cards)
        self.mod_caption = QLabel("")
        self.mod_caption.setWordWrap(True)
        mods.addWidget(self.mod_caption)
        self.mod_link = QPushButton("Mod page & artwork credits")
        self.mod_link.clicked.connect(lambda: self.open_url(self.state.mod["homepage"]) if self.state.mod else None)
        mods.addWidget(self.mod_link)
        layout.addWidget(self.mod_section)
        self.play_note = QLabel("")
        self.play_note.setWordWrap(True)
        layout.addWidget(self.play_note)
        request_note = QLabel("Missing your favourite mod? Suggest it with its official page; we’ll check engine compatibility and asset requirements.")
        request_note.setWordWrap(True)
        layout.addWidget(request_note)
        request_link = QPushButton("Request a mod on GitHub")
        request_link.clicked.connect(self.request_mod)
        layout.addWidget(request_link)
        layout.addStretch()

    def choose_game(self, game):
        if self.state.busy or self.state.game_running or self.state.steam_starting or self.state.values.get("install") == "busy": return
        if game not in self.game_buttons: return
        self.state.selected_game = game
        self.state.selected_profile = game
        self.state.steam_target = None
        self.play_after_steam = False
        self.step = 0
        self.notice.setText("")
        self.refresh_view()

    def choose_profile(self, profile):
        if self.state.busy or self.state.game_running or self.state.steam_active or self.state.steam_starting: return
        self.state.selected_profile = self.state.selected_game if profile == "original" else profile
        self.state.steam_target = None
        self.play_after_steam = False
        self.refresh_view()

    def go_to(self, index):
        if self.state.can_enter(index):
            self.step = index
            self.refresh_view()

    def continue_setup(self):
        for index in (3, 2, 1):
            if self.state.can_enter(index):
                self.go_to(index)
                return

    def refresh_view(self):
        if self.state.steam_active or (self.steam_start_deadline is not None and time.monotonic() >= self.steam_start_deadline):
            self.state.steam_starting = False
            self.steam_start_deadline = None
        accent = "#" + self.state.game["accent"].lower()
        self.setStyleSheet(STYLE.replace("#efad40", accent).replace("#101619", QColor(accent).darker(850).name()))
        self.notice.setStyleSheet(f"color:{accent};")
        self.steam_help_title.setStyleSheet(f"color:{accent}; font-weight:bold;")
        self.choose_title.setText(self.state.game["title"].upper())
        self.choose_summary.setText(self.state.game["summary"])
        self.choose_engine.setText(f'POWERED BY {self.state.game["engine"].upper()}\n\n' + ("Native OpenRA using owned Steam assets. Rules, balance and missions differ from the original games." if self.state.classic else self.state.sage_copy["detail"] if self.state.sage else "Experimental Wine + cnc-ddraw using owned Steam files. Gameplay, graphics and Steam launch validation pending." if self.state.compatibility else "Native GeneralsX using your owned Steam assets."))
        tint = QColor(accent)
        self.choose_engine_panel.setStyleSheet(f"QFrame {{ background:rgba({tint.red()},{tint.green()},{tint.blue()},20); border:1px solid {accent}; }} QLabel {{ background:transparent; border:none; }}")
        self.choose_logo.setText(self.state.game["emblem"])
        self.choose_logo.setStyleSheet(f"color:{accent}; font-size:28px; font-weight:bold;")
        pixmap = self.game_logo_pixmaps.get(self.state.selected_game)
        if pixmap is not None:
            self.choose_logo.setPixmap(pixmap.scaled(200, 110, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation))
            if "original" in self.image_labels:
                self.image_labels["original"].setPixmap(pixmap.scaled(130, 90, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
        self.choose_note.setText("Own Red Alert and C&C on Steam. OpenRA needs C&C’s desert tileset; setup downloads both owned games." if self.state.selected_game == "ra" else "Own this game through Steam’s Ultimate Collection. Remastered assets are not used in this setup.")
        if not self.state.busy and not self.state.game_running:
            while self.step > 0 and not self.state.can_enter(self.step):
                self.step -= 1
        self.pages.setCurrentIndex(self.step)
        for index, button in enumerate(self.step_buttons):
            marker = "✓" if index != self.step and self.state.complete(index) else str(index + 1)
            title = ("CHOOSE GAME", "PREPARE LINUX", "STEAM DOWNLOAD", "PLAY")[index]
            button.setText(f"{marker}  {title}")
            button.setEnabled(self.state.can_enter(index))
            button.setChecked(index == self.step)
        for game, button in self.game_buttons.items():
            button.setObjectName("selected" if game == self.state.selected_game else "")
            button.style().unpolish(button); button.style().polish(button)
            button.setEnabled(not self.state.busy and not self.state.game_running and not self.state.steam_starting and self.state.values.get("install") != "busy")
            color = "#" + next(item["accent"] for item in self.state.games if item["id"] == game)
            border = f"border:1px solid {color};" if game == self.state.selected_game else "border:1px solid #354044;"
            button.setStyleSheet(f"QPushButton {{ text-align:left; font-weight:bold; color:{color}; {border} }} QLabel {{ border:none; background:transparent; color:{color}; }}")
        self.continue_button.setEnabled(self.state.can_enter(1))
        self.sage_steam_button.setVisible(self.state.sage)
        self.sage_steam_button.setEnabled(self.state.can_enter(1))
        instructions = (["1  Sign in only in the native Linux Steam client. Install the English game.", "2  In Steam Properties → Compatibility, enable Proton 11 and start the game once to finish setup.", "3  Return here. Play unlocks after Steam files and Proton are detected."] if self.state.sage else ["1  Sign in locally with your Steam account login name, not your display name.", "2  Enter your password and newest Steam Guard code only in the Steam terminal.", "3  Keep it open until the download finishes. Play unlocks after validation."])
        for label, text in zip(self.steam_instruction_labels, instructions): label.setText(text)
        self.steam_guide_button.setVisible(not self.state.sage)
        self.steam_security_note.setText("Steam handles authentication, downloads and Proton updates. Your password and Steam Guard stay in Valve’s client; this launcher does not receive them. Optional archive scans do not cover Steam-managed downloads." if self.state.sage else self.state.guide_copy["securityDetail"])
        self.signin_button.setText("OPEN STEAM INSTALL →" if self.state.sage else "SIGN IN TO STEAM →")
        self.prepare_button.setEnabled(self.state.can_enter(1))
        self.engine_row.setText(("✓  " if self.state.engine_ready else "○  ") + ("Compatibility " if self.state.compatibility else "Native ") + self.state.game["engine"] + " engine")
        self.steam_row.setText(("✓  " if self.state.values.get("steam") == "ready" else "○  ") + ("Native Linux Steam client" if self.state.sage else "Valve Steam downloader and Linux support"))
        self.signin_button.setEnabled(self.state.can_enter(2) and not self.state.steam_active and not self.state.steam_starting and self.state.values.get("install") != "busy")
        self.steam_help_title.setText("Steam Proton setup" if self.state.sage else self.state.steam_guidance["title"])
        self.steam_help_detail.setText(self.state.sage_copy["prepare"] if self.state.sage else self.state.steam_guidance["detail"])
        self.play_title.setText(self.state.title)
        self.play_summary.setText(self.state.mod["summary"] if self.state.mod else ("OpenRA is ready. Modernized gameplay using your owned Steam assets." if self.state.classic else "Your original game is ready to deploy."))
        self.play_button.setText("GAME RUNNING" if self.state.game_running else ("INSTALL & PLAY →" if self.state.needs_install else "PLAY →"))
        self.play_button.setEnabled(self.state.can_enter(3))
        self.fullscreen.setEnabled(not self.state.busy and not self.state.game_running)
        self.graphics.setEnabled(not (self.state.classic or self.state.compatibility) and not self.state.busy and not self.state.game_running)
        self.graphics.setVisible(not (self.state.classic or self.state.compatibility))
        self.graphics_label.setVisible(not (self.state.classic or self.state.compatibility))
        self.graphics.setToolTip("OpenRA uses its own in-game graphics settings." if self.state.classic else "")
        self.play_note.setText(self.state.sage_copy["play"] if self.state.sage else "Experimental Wine support. Windowed 1280×720 upscaling; borderless fullscreen. Firestorm is available in Tiberian Sun’s menu. CnCNet is not installed yet." if self.state.compatibility else "OpenRA uses its own graphics settings. Windowed mode uses 1280×720; fullscreen follows the desktop." if self.state.classic else "Windowed mode uses 1280×720; Balanced is recommended. Zero Hour mod support is experimental.")
        self.mod_section.setVisible(bool(self.state.available_mods))
        for profile, button in self.profile_buttons.items():
            visible = profile == "original" or any(mod["id"] == profile for mod in self.state.available_mods)
            self.profile_panels[profile].setVisible(visible)
            if profile == "original": button.setText(self.state.game["title"].replace("&", "&&"))
            button.setObjectName("selected" if (profile == "original" and self.state.mod is None) or profile == self.state.profile else "")
            button.style().unpolish(button); button.style().polish(button)
            button.setEnabled(not self.state.busy and not self.state.game_running)
        if self.steam_guide is not None:
            self.steam_guide.refresh()
        mod = self.state.mod
        self.mod_caption.setText(f'{mod["version"]} · Experimental support' if mod else "Original " + self.state.game["title"] + " · No mod active")
        self.mod_link.setVisible(mod is not None)
        self.progress.setVisible(self.state.busy)
        self.help_menu.setEnabled(not self.state.busy and not self.state.game_running)
        if self.step == 3 and self.load_media and not self.media_loaded:
            self.media_loaded = True
            for item in self.state.mods:
                self.fetch_image(item)

    def environment(self):
        environment = QProcessEnvironment.systemEnvironment()
        environment.insert("GX_INSTALL_ROOT", str(ROOT))
        environment.insert("GX_SCAN_DOWNLOADS", "1" if self.state.scan_downloads else "0")
        return environment

    def read_status(self):
        if self.status_worker is not None:
            return
        process = QProcess(self)
        self.status_worker = process
        process.setProcessEnvironment(self.environment())
        process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        def finished(code, status):
            text = bytes(process.readAllStandardOutput()).decode(errors="replace")
            if code == 0:
                previous_ready = self.state.assets_ready
                self.state.update(text)
                if self.waiting_dependencies and self.state.tools_ready:
                    self.waiting_dependencies = False
                    self.run_actions([("engine", self.state.selected_game), ("steam", self.state.selected_game)])
                if self.state.can_enter(3) and (not previous_ready or self.step == 2):
                    self.step = 3
                elif self.step == 1 and self.state.can_enter(2):
                    self.step = 2
            else:
                self.notice.setText(text[-1000:])
            self.status_worker = None
            process.deleteLater()
            self.refresh_view()
            if self.play_after_steam and self.state.mod and not self.state.needs_install and self.state.can_enter(3):
                self.play_after_steam = False
                self.start_game()
        process.finished.connect(finished)
        process.start("/bin/bash", [str(self.backend), "status", self.state.selected_game])

    def run_actions(self, actions, play_after=False):
        if self.state.busy or self.state.game_running:
            return
        self.queue = list(actions)
        self.play_after_install = play_after
        self.state.busy = True
        self.output = ""
        self.refresh_view()
        self.next_action()

    def next_action(self):
        if not self.queue:
            self.state.busy = False
            self.read_status()
            if self.play_after_install:
                self.play_after_install = False
                self.start_game()
            elif self.state.can_enter(2) and self.step == 1:
                self.step = 2
            self.refresh_view()
            return
        action = self.queue.pop(0)
        self.notice.setText("Working: " + action[0])
        process = QProcess(self)
        self.worker = process
        process.setProcessEnvironment(self.environment())
        process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        def output():
            self.output = (self.output + bytes(process.readAllStandardOutput()).decode(errors="replace"))[-12000:]
            self.details.setPlainText(self.output)
        def finished(code, status):
            output()
            self.worker = None
            process.deleteLater()
            if code != 0:
                self.queue = []
                if "NATIVE_ASSETS_REQUIRED" in self.output and action[0] == "native-mod":
                    self.play_after_steam = self.play_after_install
                    self.play_after_install = False
                    self.state.busy = False
                    self.state.steam_target = action[1]
                    self.state.values["native_engine_" + action[1]] = "ready"
                    self.state.values["steam"] = "ready"
                    self.step = 2
                    self.signin()
                    return
                self.play_after_install = False
                self.state.busy = False
                advice = self.state.recovery_for(self.output)
                self.notice.setText(advice["title"] + " — " + advice["message"])
                self.read_status()
                self.refresh_view()
            else:
                self.notice.setText("Step completed.")
                self.next_action()
        process.readyReadStandardOutput.connect(output)
        process.finished.connect(finished)
        process.start("/bin/bash", [str(self.backend), *action])

    def prepare(self):
        if not self.state.can_enter(1): return
        if not self.state.tools_ready:
            self.waiting_dependencies = True
            self.open_terminal("Linux dependencies", ["linux-tools", self.state.selected_game])
        else:
            self.run_actions([("engine", self.state.selected_game), ("steam", self.state.selected_game)])
        if self.state.sage: self.notice.setText(self.state.sage_copy["prepare"])

    def show_security(self):
        dialog = SecuritySetupWindow(self)
        dialog.exec()

    def show_community(self):
        dialog = CommunityWindow(self)
        dialog.exec()

    def show_steam_guide(self):
        if self.steam_guide is None:
            self.steam_guide = SteamGuideWindow(self)
            screen = self.screen().availableGeometry()
            self.steam_guide.move(screen.right() - self.steam_guide.width() - 16, screen.top() + 24)
        self.steam_guide.refresh()
        self.steam_guide.show()
        self.steam_guide.raise_()

    def signin(self):
        if not self.state.can_enter(2) or self.state.steam_active or self.state.steam_starting or self.state.values.get("install") == "busy":
            return
        if self.state.sage:
            self.run_actions([("steam-login", self.state.steam_profile)])
            return
        self.steam_launch_error = None
        self.state.steam_starting = True
        self.show_steam_guide()
        if self.open_terminal("Steam sign-in", ["steam-login", self.state.steam_profile]):
            self.steam_start_deadline = time.monotonic() + 15
        else:
            self.state.steam_starting = False
            self.steam_launch_error = self.notice.text()
        self.refresh_view()

    def open_terminal(self, title, arguments):
        ROOT.mkdir(parents=True, exist_ok=True)
        script = ROOT / (title.lower().replace(" ", "-") + ".sh")
        command = shlex.join(["/bin/bash", str(self.backend), *arguments])
        script.write_text(f'#!/bin/bash\nexport GX_INSTALL_ROOT={shlex.quote(str(ROOT))}\nexport GX_SCAN_DOWNLOADS={"1" if self.state.scan_downloads else "0"}\n{command}\nresult=$?\nprintf "\\nReturn to the launcher. Press Return to close.\\n"\nread -r\nexit "$result"\n')
        script.chmod(0o700)
        for program, prefix in [("x-terminal-emulator", ["-e"]), ("gnome-terminal", ["--"]), ("konsole", ["-e"]), ("xfce4-terminal", ["-x"]), ("xterm", ["-e"])]:
            if shutil.which(program):
                try:
                    subprocess.Popen([program, *prefix, "/bin/bash", str(script)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                except OSError:
                    continue
                self.notice.setText("Complete " + title.lower() + " in the terminal. Never enter your password in this launcher.")
                return True
        self.waiting_dependencies = False
        self.notice.setText("No supported terminal was found. Install your desktop terminal, then retry.")
        return False

    def play(self):
        if not self.state.can_enter(3): return
        if self.state.needs_install:
            answer = QMessageBox.question(self, "Install & Play?", "Install " + self.state.mod["title"] + "? " + ("This installs a pinned native OpenRA runtime and uses only owned Steam assets. Tiberian Dawn HD requires Remastered Collection and up to 40 GB; Combined Arms requires C&C and Red Alert. Steam sign-in opens if assets are missing." if self.state.mod["native"] else "Allow up to 8 GB. Data comes from GenLauncher’s mirror with pinned hashes. Your normal game stays separate.") + " Gameplay support is experimental.")
            if answer == QMessageBox.StandardButton.Yes:
                self.run_actions([("native-mod" if self.state.mod["native"] else "mod", self.state.profile)], play_after=True)
        else:
            self.start_game()

    def start_game(self):
        if self.state.game_running: return
        self.state.game_running = True
        profile = self.state.profile
        self.state.busy = False
        quality = "maximum" if self.graphics.currentIndex() else "balanced"
        process = QProcess(self)
        self.worker = process
        process.setProcessEnvironment(self.environment())
        process.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        def graphics_done(code, status):
            process.deleteLater()
            if code != 0:
                self.state.game_running = False
                self.notice.setText("Could not save graphics settings. Check that no other game is running.")
                self.refresh_view()
                return
            game = QProcess(self)
            self.worker = game
            game.setProcessEnvironment(self.environment())
            def closed(code, status):
                if self.worker is not game:
                    game.deleteLater()
                    return
                self.state.game_running = False
                self.worker = None
                game.deleteLater()
                self.notice.setText("Game closed." if code == 0 else "Game stopped. Use Help to repair the engine, or inspect the profile log.")
                self.read_status()
                self.refresh_view()
            game.finished.connect(closed)
            screen = QApplication.primaryScreen()
            size = screen.size() if screen else None
            width, height = (size.width(), size.height()) if self.fullscreen.isChecked() and size else (1280, 720)
            game.start("/bin/bash", [str(self.backend), "launch", profile, "-fullscreen" if self.fullscreen.isChecked() else "-win", "-xres", str(width), "-yres", str(height)])
        process.finished.connect(graphics_done)
        process.start("/bin/bash", [str(self.backend), "graphics", profile if profile in [game["id"] for game in self.state.games] or (self.state.mod and self.state.mod["native"]) else "vanilla", quality])
        self.refresh_view()

    def set_game_logo(self, id, pixmap):
        self.game_logo_pixmaps[id] = pixmap
        self.game_logo_labels[id].setPixmap(pixmap.scaled(172, 70, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation))
        if id == self.state.selected_game and "original" in self.image_labels:
            self.image_labels["original"].setPixmap(pixmap.scaled(130, 90, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
        if self.state.selected_game == id:
            self.choose_logo.setPixmap(pixmap.scaled(200, 110, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation))

    def fetch_game_logos(self):
        for game in self.state.games:
            request = QNetworkRequest(QUrl(f'https://cdn.akamai.steamstatic.com/steam/apps/{game["steam_id"]}/logo.png'))
            request.setTransferTimeout(15000)
            reply = self.network.get(request)
            def finished(response=reply, id=game["id"]):
                data = bytes(response.readAll())
                pixmap = QPixmap()
                if len(data) <= 2_000_000 and pixmap.loadFromData(data):
                    self.set_game_logo(id, pixmap)
                response.deleteLater()
            reply.finished.connect(finished)

    def fetch_image(self, mod):
        reply = self.network.get(QNetworkRequest(QUrl(mod["image"])))
        def finished():
            pixmap = QPixmap()
            if pixmap.loadFromData(bytes(reply.readAll())):
                self.image_labels[mod["id"]].setPixmap(pixmap.scaled(130, 90, Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation))
            reply.deleteLater()
        reply.finished.connect(finished)

    def check_updates(self):
        self.update_label.setText("Checking releases…")
        reply = self.network.get(QNetworkRequest(QUrl("https://api.github.com/repos/" + self.state.product["repository"] + "/releases?per_page=10")))
        def finished():
            try:
                releases = json.loads(bytes(reply.readAll()))
                if not isinstance(releases, list): raise ValueError()
                release = next(item for item in releases if not item["draft"] and any(asset["name"] == self.state.product["linux_archive"] for asset in item["assets"]))
                version = re.fullmatch(r"v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?", release["tag_name"])
                current = tuple(map(int, self.state.product["version"].split(".")))
                if version and tuple(map(int, version.groups())) > current:
                    self.update_url = "https://github.com/" + self.state.product["repository"] + "/releases/tag/" + release["tag_name"]
                    self.update_label.setText("Update available — open release")
                    self.update_link.show()
                else:
                    self.update_link.hide()
                    self.update_label.setText("Launcher is up to date.")
            except (ValueError, StopIteration, KeyError, TypeError):
                self.update_label.setText("No downloadable Linux release yet.")
            reply.deleteLater()
        reply.finished.connect(finished)

    def help_action(self, index):
        self.help_menu.setCurrentIndex(0)
        if index == 1: self.prepare()
        elif index == 2: self.go_to(2)
        elif index == 3 and self.state.mod: self.run_actions([("native-mod" if self.state.mod["native"] else "mod", self.state.profile)])
        elif index == 4: QDesktopServices.openUrl(QUrl.fromLocalFile(str(ROOT)))
        elif index == 5: self.open_url("https://help.steampowered.com/en/wizard/HelpWithLogin")
        elif index == 6: self.show_steam_guide()
        elif index == 7: self.show_online_setup()
        elif index == 8: self.show_security()

    def show_online_setup(self):
        self.online_window = OnlineSetupWindow(self)
        self.online_window.show()

    def request_mod(self):
        query = urlencode({"template": "mod-request.md", "title": "Mod request: " + self.state.game["title"]})
        self.open_url("https://github.com/" + self.state.product["repository"] + "/issues/new?" + query)

    @staticmethod
    def open_url(url):
        QDesktopServices.openUrl(QUrl(url))

    def closeEvent(self, event):
        if self.state.busy or self.state.game_running:
            QMessageBox.information(self, "Keep the launcher open", "Finish the installation or quit your game normally before closing the launcher.")
            event.ignore()
        else:
            if self.steam_guide is not None:
                self.steam_guide.close()
            event.accept()


def main():
    if sys.platform != "linux":
        raise SystemExit("Use the native SwiftUI launcher on macOS. This UI is for Linux.")
    if "--self-check" in sys.argv:
        state = LauncherState(RESOURCES)
        for name in ("downloads.sh", "security.sh", "backend.sh", "platform-linux.sh", "steam-status.sh", "classic.sh", "compatibility.sh", "sage.sh"):
            subprocess.run(["/bin/bash", "-n", str(RESOURCES / "scripts" / name)], check=True)
        if len(state.mods) != 7 or len(state.policy["steps"]) != 4:
            raise SystemExit("Packaged catalog or setup policy is incomplete.")
        print("Linux package resources and native Qt imports passed; no windows or games launched.")
        return 0
    application = QApplication(sys.argv)
    application.setApplicationName("C&C Unix Launcher")
    if "--ui-smoke-test" in sys.argv or "--steam-guide-smoke-test" in sys.argv:
        window = LauncherWindow(auto_poll=False, load_media=False)
        window.show()
        if "--steam-guide-smoke-test" in sys.argv:
            window.state.update("platform=ready\nengine=ready\nsteam=ready\ninstall=busy\nsteam_session_vanilla=active\nsteam_download_vanilla=waiting-password")
            window.show_steam_guide()
            console = QMainWindow()
            console.setWindowTitle("Synthetic console — no Steam process")
            console.setCentralWidget(QLabel("A normal window used to check guide visibility and keyboard focus."))
            console.show()
            console.activateWindow()
            application.processEvents()
            window.state.values["steam_download_vanilla"] = "awaiting-guard"
            window.refresh_view()
            application.processEvents()
            if not window.steam_guide.isVisible() or window.steam_guide.status_title.text() != window.state.guidance["awaiting-guard"]["title"]:
                raise SystemExit("The separate Steam guide did not stay visible and update.")
            if application.activeWindow() is not console:
                raise SystemExit("Guide updates stole focus from the synthetic console.")
            QTimer.singleShot(200, application.quit)
            result = application.exec()
            print("Packaged Steam guide stayed visible and updated beside a focused synthetic console; no Steam, network or games started.")
            return result
        application.processEvents()
        if window.step_buttons[2].isEnabled() or window.step_buttons[3].isEnabled():
            raise SystemExit("Unvalidated steps were enabled in the packaged UI.")
        QTimer.singleShot(200, application.quit)
        result = application.exec()
        print("Packaged Linux window rendered with locked steps; no network, sign-in or game launches.")
        return result
    window = LauncherWindow()
    window.show()
    return application.exec()


if __name__ == "__main__":
    sys.exit(main())
