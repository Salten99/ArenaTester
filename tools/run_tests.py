"""Runs the game's tests headless (tools/run_tests.bat calls this) and fails on engine errors too.

A test can pass while Godot prints "ERROR:" lines (a freed node, a zero-sized bone). Those are
bugs, so any ERROR line not in EXPECTED fails the run. Usage: run_tests.py <godot exe> <game folder>
"""
import subprocess
import sys

# Errors the tests cause on purpose, or that only exist on this machine.
EXPECTED = [
    "Parse JSON failed",           # the broken-profile test feeds a broken profile
    "/asset_library/",              # the asset viewer test: asset_library is local only, not in git
    "leaked at exit",               # Godot's own exit bookkeeping, not the game's
    "resources still in use at exit",
]


def main() -> int:
    godot, game = sys.argv[1], sys.argv[2]
    proc = subprocess.Popen([godot, "--headless", "--path", game, "--fixed-fps", "60", "res://tests/test_main.tscn"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
    errors = []
    for line in proc.stdout:
        print(line, end="")
        if line.startswith("ERROR:") and not any(e in line for e in EXPECTED):
            errors.append(line.strip())
    code = proc.wait()
    if errors:
        print("\n%d unexpected engine error(s), the first ones:" % len(errors))
        for e in errors[:10]:
            print("  " + e)
        return code or 1
    return code


if __name__ == "__main__":
    sys.exit(main())
