const PAUSED_SHORTCUTS = ["-", "="];

function isInputElement(target) {
  return (
    target.tagName === "INPUT" ||
    target.tagName === "TEXTAREA" ||
    target.tagName === "SELECT" ||
    target.isContentEditable ||
    target.closest?.("[contenteditable='true']")
  );
}

export function setupCanvasKeyboard(
  keyboardShortcutsService,
  actions,
  canvasElement
) {
  keyboardShortcutsService.pause(PAUSED_SHORTCUTS);

  const bindings = {
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
    "meta::c": (e) => {
      e.preventDefault();
      actions.onCopy?.();
    },
    "meta::x": (e) => {
      e.preventDefault();
      actions.onCut?.();
    },
    "::delete": () => actions.onDelete?.(),
    "::backspace": () => actions.onDelete?.(),
    "::escape": () => actions.onEscape?.(),
    "::+": () => actions.onZoomIn?.(),
    "::=": () => actions.onZoomIn?.(),
    "::-": () => actions.onZoomOut?.(),
    "::Digit1": () => actions.onFitToView?.(),
    "::Digit2": () => actions.onAutoLayout?.(),
  };

  const handler = (event) => {
    if (event.repeat) {
      return;
    }
    if (isInputElement(event.target)) {
      return;
    }
    const meta = event.metaKey || event.ctrlKey ? "meta" : "";
    const shift = event.shiftKey ? "shift" : "";
    const key = event.key.toLowerCase();
    const binding =
      bindings[`${meta}:${shift}:${key}`] ??
      bindings[`${meta}:${shift}:${event.code}`];
    binding?.(event);
  };

  const pasteHandler = (event) => {
    if (isInputElement(event.target)) {
      return;
    }

    actions.onPaste?.(event);
  };

  const copyHandler = (event) => {
    if (isInputElement(event.target)) {
      return;
    }

    event.preventDefault();
    actions.onCopy?.();
  };

  const cutHandler = (event) => {
    if (isInputElement(event.target)) {
      return;
    }

    event.preventDefault();
    actions.onCut?.();
  };

  canvasElement.addEventListener("keydown", handler);
  canvasElement.addEventListener("paste", pasteHandler);
  canvasElement.addEventListener("copy", copyHandler);
  canvasElement.addEventListener("cut", cutHandler);

  return {
    teardown() {
      canvasElement.removeEventListener("keydown", handler);
      canvasElement.removeEventListener("paste", pasteHandler);
      canvasElement.removeEventListener("copy", copyHandler);
      canvasElement.removeEventListener("cut", cutHandler);
      try {
        keyboardShortcutsService.unpause(PAUSED_SHORTCUTS);
      } catch {
        // keyboard shortcuts may not be fully initialized
      }
    },
  };
}
