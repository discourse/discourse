import { getOwner } from "@ember/owner";
import type WireframeBlockMutations from "../services/wireframe-block-mutations";
import type WireframeClipboard from "../services/wireframe-clipboard";
import type WireframeWorkspace from "../services/wireframe-workspace";

/**
 * Keyboard-shortcut bindings for the wireframe. Attaches a `keydown`
 * listener at the document level while the editor is active. Each
 * shortcut is gated by a focus check so the editor doesn't intercept
 * typing inside form inputs or contenteditable surfaces.
 *
 * - `Cmd/Ctrl + C` → copy the selected block to the clipboard.
 * - `Cmd/Ctrl + X` → cut the selected block (clipboard + remove).
 * - `Cmd/Ctrl + V` → paste the clipboard entry after the current
 *   selection.
 * - `Delete` or `Backspace` → remove the selected block. (Distinct
 *   shortcut from cut because users tend to want delete to discard,
 *   not stash on the clipboard.)
 */

/**
 * Returns true when the focused element is a text-input surface and the
 * editor should NOT intercept the keystroke. Otherwise the shortcuts
 * would clobber normal Cmd-C/V inside the inspector's form fields.
 */
function isTypingFocus(): boolean {
  const el = document.activeElement;
  if (!el) {
    return false;
  }
  const tag = el.tagName;
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") {
    return true;
  }
  if (
    el instanceof HTMLElement &&
    (el.isContentEditable || el.getAttribute("contenteditable") === "true")
  ) {
    return true;
  }
  return false;
}

function isModifier(event: KeyboardEvent): boolean {
  return event.metaKey || event.ctrlKey;
}

/**
 * Installs the document-level keydown listener and returns a `detach`
 * thunk the caller can invoke to remove it. Designed for ergonomic use
 * from an effect-style observer that runs whenever the editor's
 * `wireframeEditMode.active` flips.
 */
export function attachEditorShortcuts(editor: WireframeWorkspace): () => void {
  function onKeyDown(event: KeyboardEvent) {
    // The listener lives at the document level for the editor's lifetime. If the
    // editor's owner has been torn down (e.g. between tests, where the listener
    // would otherwise leak), bail before reading anything off it — a destroyed
    // service throws when a shortcut path resolves an injected dependency on the
    // dead owner. `isDestroyed`/`isDestroying` are plain instance flags, so
    // reading them never triggers a lookup.
    if (
      editor.isDestroyed ||
      editor.isDestroying ||
      !editor.wireframeEditMode.active
    ) {
      return;
    }
    if (isTypingFocus()) {
      return;
    }

    if (event.key === "Delete" || event.key === "Backspace") {
      const key = editor.wireframeSelection.selectedBlockKey;
      if (!key) {
        return;
      }
      event.preventDefault();
      // Resolve the block-mutations service lazily — only after the
      // destroyed/active gate above has confirmed the owner is still alive.
      const mutations = getOwner(editor)!.lookup(
        "service:wireframe-block-mutations"
      ) as WireframeBlockMutations;
      // Under a multi-selection, remove the whole set in one undo step;
      // otherwise just the single selected block.
      if (editor.wireframeSelection.selectionCount > 1) {
        mutations.removeBlocks(
          editor.wireframeSelection.selectedKeysSnapshot()
        );
      } else {
        mutations.removeBlock(key);
      }
      return;
    }

    if (!isModifier(event)) {
      return;
    }

    // Resolve the clipboard service lazily — only on a modifier shortcut, and
    // only after the destroyed/active gate above has confirmed the owner is
    // still alive (a lookup on a torn-down owner would throw).
    const clipboard = getOwner(editor)!.lookup(
      "service:wireframe-clipboard"
    ) as WireframeClipboard;

    const key = event.key.toLowerCase();
    if (key === "c") {
      if (!editor.wireframeSelection.selectedBlockKey) {
        return;
      }
      event.preventDefault();
      clipboard.copySelected();
      return;
    }
    if (key === "x") {
      if (!editor.wireframeSelection.selectedBlockKey) {
        return;
      }
      event.preventDefault();
      clipboard.cutSelected();
      return;
    }
    if (key === "v") {
      if (
        !clipboard.hasClipboardEntry ||
        !editor.wireframeSelection.selectedBlockKey
      ) {
        return;
      }
      event.preventDefault();
      clipboard.pasteFromClipboard();
    }
  }

  document.addEventListener("keydown", onKeyDown);
  return function detachEditorShortcuts() {
    document.removeEventListener("keydown", onKeyDown);
  };
}
