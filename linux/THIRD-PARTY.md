# Linux package dependencies

The Linux launcher uses dynamically loaded Qt libraries through PySide6.
PySide6 and Shiboken are provided by The Qt Company under their applicable
LGPL/GPL/commercial licenses; this package uses the open-source distribution.
License texts are included in `licenses/`. Package distribution metadata is
also retained. These libraries are dynamically linked; no Qt library is modified.

Source and licensing: https://code.qt.io/pyside/pyside-setup.git
Qt licensing: https://doc.qt.io/qtforpython-6/licenses.html

The package keeps Qt libraries as separate shared objects under `_internal`;
they can be replaced by compatible user-built versions. The launcher's source,
including its build command, is available in this repository. Qt source is
available from https://download.qt.io/official_releases/qt/.

PyInstaller packages the application and has a bootloader exception permitting
distribution of applications under their own licenses. See
https://pyinstaller.org/en/stable/license.html.

Game engines, SteamCMD and mod data are downloaded separately. They retain
their own licenses and are not included in the launcher archive.
