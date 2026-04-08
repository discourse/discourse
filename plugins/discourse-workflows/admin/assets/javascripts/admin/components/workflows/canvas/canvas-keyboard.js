const PAUSED_SHORTCUTS = ["-", "="];

function isInputElement(target) {
  return target.tagName === "INPUT" || target.tagName === "TEXTAREA";
}

export function setupCanvasKeyboard(keyboardShortcutsService, actions) {
  keyboardShortcutsService.pause(PAUSED_SHORTCUTS);

  const keyActions = {
    "meta::z": (e) => {
      e.preventDefault();
      actions.onUndo?.();
    },
    "meta:shift:z": (e) => {
      e.preventDefault();
      actions.onRedo?.();
    },
    "meta::y": (e) => {
      e.preventDefault();
      actions.onRedo?.();
    },
    "meta::c": () => actions.onCopy?.(),
    "meta::v": () => actions.onPaste?.(),
    "::delete": () => actions.onDelete?.(),
    "::backspace": () => actions.onDelete?.(),
    "::escape": () => actions.onEscape?.(),
    "::+": () => actions.onZoomIn?.(),
    "::=": () => actions.onZoomIn?.(),
    "::-": () => actions.onZoomOut?.(),
  };

  const codeActions = {
    "::Digit1": () => actions.onFitToView?.(),
    "::Digit2": () => actions.onAutoLayout?.(),
  };

  const handler = (event) => {
    if (isInputElement(event.target)) {
      return;
    }
    const meta = event.metaKey || event.ctrlKey ? "meta" : "";
    const shift = event.shiftKey ? "shift" : "";
    const key = event.key.toLowerCase();
    const action =
      keyActions[`${meta}:${shift}:${key}`] ??
      codeActions[`${meta}:${shift}:${event.code}`];
    action?.(event);
  };

  document.addEventListener("keydown", handler);

  return {
    teardown() {
      document.removeEventListener("keydown", handler);
      try {
        keyboardShortcutsService.unpause(PAUSED_SHORTCUTS);
      } catch {
        // keyboard shortcuts may not be fully initialized
      }
    },
  };
}
