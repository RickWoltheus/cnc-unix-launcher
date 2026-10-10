/* SPDX-License-Identifier: MIT
 * Steam CEF compatibility approach: https://github.com/notpop/steam-on-m1-wine
 * This helper forwards arguments without logging them or handling credentials.
 */
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <stdlib.h>
#include <stdio.h>
#include <wchar.h>

int wmain(void) {
    wchar_t *path = calloc(32768, sizeof(wchar_t));
    if (!path) return 1;
    DWORD length = GetModuleFileNameW(NULL, path, 32768);
    if (!length || length >= 32768) { free(path); return 1; }
    wchar_t *slash = wcsrchr(path, L'\\');
    if (!slash || (size_t)(slash - path) + 40 >= 32768) { free(path); return 1; }
    wcscpy(slash + 1, L"steamwebhelper.cnc-original.exe");
    const wchar_t *tail = GetCommandLineW();
    int quoted = 0;
    while (*tail) {
        if (*tail == L'"') quoted = !quoted;
        else if (*tail == L' ' && !quoted) break;
        ++tail;
    }
    while (*tail == L' ') ++tail;
    size_t capacity = wcslen(path) + wcslen(tail) + 64;
    if (capacity > 32767) { free(path); return 1; }
    wchar_t *command = calloc(capacity, sizeof(wchar_t));
    if (!command) { free(path); return 1; }
    _snwprintf(command, capacity, L"\"%ls\" --disable-gpu --single-process %ls", path, tail);
    STARTUPINFOW startup = {0};
    PROCESS_INFORMATION process = {0};
    startup.cb = sizeof(startup);
    if (!CreateProcessW(path, command, NULL, NULL, TRUE, 0, NULL, NULL, &startup, &process)) {
        free(command); free(path); return 1;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD result = 1;
    GetExitCodeProcess(process.hProcess, &result);
    CloseHandle(process.hProcess);
    CloseHandle(process.hThread);
    free(command); free(path);
    return (int)result;
}
