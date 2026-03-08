"""
Context-aware horizontal navigation kitten.

Usage: kitten navigate_or_tab.py <left|right>

If the current tab has multiple panes, moves focus to the neighboring pane.
If there is only one pane (no splits), switches to the previous/next tab instead.
"""


def main(args):
    pass


def handle_result(args, answer, target_window_id, boss):
    direction = args[1] if len(args) > 1 else "right"
    tab = boss.active_tab
    if tab is None:
        return

    if len(tab.windows) > 1:
        tab.neighboring_window(direction)
    else:
        boss.activate_tab_relative(-1 if direction == "left" else 1)
