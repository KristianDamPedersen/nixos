import json
import subprocess

windows = {}

with subprocess.Popen(
    ["niri", "msg", "--json", "event-stream"],
    stdout=subprocess.PIPE,
    text=True
) as events:
    for line in events.stdout:
        event = json.loads(line)

        # Initial snapshot: remember existing windows without resizing them.
        if "WindowsChanged" in event:
            windows = {
                w["id"]: w
                for w in event["WindowsChanged"]["windows"]
            }

        elif "WindowClosed" in event:
            windows.pop(event["WindowClosed"]["id"], None)

        elif "WindowOpenedOrChanged" in event:
            window = event["WindowOpenedOrChanged"]["window"]
            window_id = window["id"]
            workspace_id = window.get("workspace_id")

            is_new = window_id not in windows
            is_tiled = not window.get("is_floating", False)

            workspace_has_tiled_window = any(
                w.get("workspace_id") == workspace_id
                and not w.get("is_floating", False)
                for w in windows.values()
            )

            windows[window_id] = window

            if (
                is_new
                and is_tiled
                and workspace_id is not None
                and not workspace_has_tiled_window
            ):
                subprocess.run(
                    [
                        "niri", "msg", "action", "set-window-width",
                        "--id", str(window_id), "100%"
                    ],
                    check=False
                )
