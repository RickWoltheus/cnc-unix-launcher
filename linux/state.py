from dataclasses import dataclass, field
import csv
import json
from pathlib import Path


@dataclass
class LauncherState:
    resources: Path
    selected_game: str = "vanilla"
    selected_profile: str = "vanilla"
    busy: bool = False
    game_running: bool = False
    wine_session_observed: bool = False
    steam_starting: bool = False
    steam_target: str | None = None
    values: dict = field(default_factory=dict)

    def __post_init__(self):
        with (self.resources / "manifests/games.tsv").open() as stream:
            self.games = [dict(zip(("id", "title", "subtitle", "engine", "steam_id", "directory", "accent", "emblem", "summary"), row)) for row in csv.reader(stream, delimiter="\t")]
        with (self.resources / "manifests/product.tsv").open() as stream:
            row = next(csv.reader(stream, delimiter="\t"))
            self.product = dict(zip(("name", "version", "repository", "mac_archive", "linux_archive", "executable"), row))
        self.distribution = json.loads((self.resources / "resources/mac-distribution.json").read_text())
        self.policy = json.loads((self.resources / "resources/setup-policy.json").read_text())
        self.guide_copy = json.loads((self.resources / "resources/steam-guide.json").read_text())
        self.guidance = json.loads((self.resources / "resources/steam-guidance.json").read_text())
        self.recovery = json.loads((self.resources / "resources/recovery-guidance.json").read_text())
        with (self.resources / "manifests/mods.tsv").open() as stream:
            self.mods = [dict(zip(("id", "title", "version", "directory", "url", "support"), row)) for row in csv.reader(stream, delimiter="\t")]
        with (self.resources / "manifests/mod-media.tsv").open() as stream:
            media = {row[0]: row[1:] for row in csv.reader(stream, delimiter="\t")}
        for mod in self.mods:
            mod["image"], mod["homepage"], mod["summary"] = media[mod["id"]]
            mod.update(native=False, games=["vanilla"], source="vanilla")
        with (self.resources / "manifests/native-mods.tsv").open() as stream:
            for row in csv.reader(stream, delimiter="\t"):
                id, title, games, version, mod_id, app, source, homepage, image, summary = row
                self.mods.append(dict(id=id, title=title, games=games.split(","), version=version, native=True, source=source,
                                      homepage=homepage, image=image, summary=summary))
        self.community = json.loads((self.resources / "resources/community.json").read_text())
        self.donations = json.loads((self.resources / "resources/donations.json").read_text())
        self.online = json.loads((self.resources / "resources/online.json").read_text())

    def update(self, text):
        self.values = dict(line.split("=", 1) for line in text.splitlines() if "=" in line)
        session = self.values.get("wine_session")
        if session in ("running", "starting", "stopping"):
            self.wine_session_observed = True
            self.game_running = True
        elif session == "idle" and self.wine_session_observed:
            self.wine_session_observed = False
            self.game_running = False

    @property
    def game(self):
        return next(game for game in self.games if game["id"] == self.selected_game)

    @property
    def classic(self):
        return self.game["engine"] == "OpenRA"

    @property
    def compatibility(self):
        return self.game["engine"] == "Wine"

    @property
    def available_mods(self):
        return [mod for mod in self.mods if self.selected_game in mod["games"]]

    @property
    def steam_profile(self):
        return self.steam_target or self.selected_game

    @property
    def steam_title(self):
        return next((mod["title"] for mod in self.mods if mod["id"] == self.steam_profile), self.game["title"])

    @property
    def engine_ready(self):
        key = "native_engine_" + self.steam_target if self.steam_target else self.selected_game + "_engine" if self.classic or self.compatibility else ("base_engine" if self.selected_game == "base" else "engine")
        return self.values.get(key) == "ready"

    @property
    def steam_status(self):
        return self.values.get("steam_download_" + self.steam_profile, "idle")

    @property
    def steam_active(self):
        return self.values.get("steam_session_" + self.steam_profile) == "active"

    @property
    def assets_ready(self):
        key = self.steam_target if self.steam_target else self.selected_game + "_assets" if self.classic or self.compatibility else ("base_assets" if self.selected_game == "base" else "assets")
        return self.values.get(key) == "ready" and not self.steam_starting and self.values.get("install") != "busy" and not self.steam_active and self.steam_status in ("idle", "complete")

    @property
    def tools_ready(self):
        return self.values.get("dependencies") == "ready" and (not self.compatibility or self.values.get("wine_dependencies") == "ready")

    @property
    def facts(self):
        return {"platform": self.values.get("platform") == "ready", "selected": self.selected_game in [game["id"] for game in self.games],
                "engine": self.engine_ready, "steam": self.values.get("steam") == "ready", "assets": self.assets_ready}

    def can_enter(self, index):
        return not self.busy and not self.game_running and 0 <= index < len(self.policy["steps"]) and all(self.facts.get(key, False) for key in self.policy["steps"][index])

    def complete(self, index):
        rules = self.policy["completed"][index]
        return bool(rules) and all(self.facts.get(key, False) for key in rules)

    @property
    def profile(self):
        return self.selected_profile if any(mod["id"] == self.selected_profile for mod in self.available_mods) else self.selected_game

    @property
    def mod(self):
        return next((mod for mod in self.mods if mod["id"] == self.profile), None)

    @property
    def title(self):
        return self.mod["title"].upper() if self.mod else self.game["title"].upper()

    @property
    def needs_install(self):
        return self.mod is not None and self.values.get(self.profile) != "ready"

    @property
    def steam_guidance(self):
        return self.guidance.get(self.steam_status, self.guidance["idle"])

    def recovery_for(self, text):
        message = text.lower()
        return next((rule for rule in self.recovery["rules"] if any(pattern in message for pattern in rule["containsAny"])), self.recovery["fallback"])
