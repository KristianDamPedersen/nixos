"""Temporarily widen the only tiled window on each workspace."""

import json
import subprocess


def set_width(window_id, width):
    return subprocess.run(
        ["niri", "msg", "action", "set-window-width", "--id", str(window_id), width],
        check=False,
    ).returncode == 0


class WorkspaceWidths:
    def __init__(self, resize=set_width):
        self.windows = {}
        self.saved_widths = {}
        self.resize = resize

    def handle(self, event):
        if "WindowsChanged" in event:
            self.windows = {
                window["id"]: window
                for window in event["WindowsChanged"]["windows"]
            }
        elif "WindowOpenedOrChanged" in event:
            window = event["WindowOpenedOrChanged"]["window"]
            self.windows[window["id"]] = window
        elif "WindowClosed" in event:
            self.windows.pop(event["WindowClosed"]["id"], None)
        elif "WindowLayoutsChanged" in event:
            for window_id, layout in event["WindowLayoutsChanged"]["changes"]:
                if window_id in self.windows:
                    self.windows[window_id]["layout"] = layout
        else:
            return

        workspaces = {}
        for window in self.windows.values():
            workspace_id = window.get("workspace_id")
            if workspace_id is not None and not window.get("is_floating", False):
                workspaces.setdefault(workspace_id, []).append(window["id"])

        singletons = {ids[0] for ids in workspaces.values() if len(ids) == 1}

        # Restore only widths we changed; other windows keep Niri's usual sizing.
        for window_id, width in list(self.saved_widths.items()):
            window = self.windows.get(window_id)
            if window is None or window.get("is_floating", False):
                # Floating windows have a separate size; do not resize those.
                del self.saved_widths[window_id]
            elif window_id not in singletons:
                if self.resize(window_id, width):
                    del self.saved_widths[window_id]

        for window_id in sorted(singletons - self.saved_widths.keys()):
            size = self.windows[window_id].get("layout", {}).get("window_size")
            # Wait for valid geometry so we can restore the original width.
            if not size or size[0] <= 0:
                continue
            width = str(size[0])
            if self.resize(window_id, "100%"):
                self.saved_widths[window_id] = width


def main():
    widths = WorkspaceWidths()
    with subprocess.Popen(
        ["niri", "msg", "--json", "event-stream"],
        stdout=subprocess.PIPE,
        text=True,
    ) as events:
        for line in events.stdout:
            widths.handle(json.loads(line))
        return events.wait()


if __name__ == "__main__":
    raise SystemExit(main())
