import { module, test } from "qunit";
import { attachEditorShortcuts } from "discourse/plugins/discourse-wireframe/discourse/lib/editor-shortcuts";

// `attachEditorShortcuts` installs a DOCUMENT-level keydown listener that lives
// for the editor service's lifetime. The listener must never act on an editor
// whose owner has been torn down — a destroyed editor's stale references throw
// when a shortcut path resolves a service on the dead owner. These tests pin
// the destroyed-editor guard so a leaked listener can't fire after teardown.
module("Unit | Discourse Wireframe | lib:editor-shortcuts", function (hooks) {
  let detach;

  hooks.afterEach(function () {
    detach?.();
    detach = null;
  });

  // Minimal stand-in for the wireframe service exposing only what the Delete
  // shortcut reads. `removed` records whether the shortcut acted. The shortcut
  // reads the selection off `wireframeSession`/`wireframeSelection` and removes
  // through `wireframeBlockMutations`, exactly as the kernel injects them.
  function buildEditor(overrides = {}) {
    const removed = [];
    return {
      wireframeSession: { active: true },
      isDestroyed: false,
      isDestroying: false,
      wireframeSelection: {
        selectedBlockKey: "para:1",
        selectionCount: 1,
        selectedKeysSnapshot: () => ["para:1"],
      },
      removed,
      wireframeBlockMutations: {
        removeBlock(key) {
          removed.push(key);
        },
        removeBlocks(keys) {
          removed.push(...keys);
        },
      },
      ...overrides,
    };
  }

  function pressDelete() {
    document.dispatchEvent(
      new KeyboardEvent("keydown", { key: "Delete", bubbles: true })
    );
  }

  test("Delete removes the selected block for a live editor", function (assert) {
    const editor = buildEditor();
    detach = attachEditorShortcuts(editor);

    pressDelete();

    assert.deepEqual(editor.removed, ["para:1"], "the shortcut acted");
  });

  test("a destroyed editor's leaked listener does not act", function (assert) {
    const editor = buildEditor();
    detach = attachEditorShortcuts(editor);

    // The owner is torn down: the service is marked destroyed but the leaked
    // document listener is still attached.
    editor.isDestroyed = true;

    pressDelete();

    assert.deepEqual(
      editor.removed,
      [],
      "the destroyed editor's handler bailed before touching any service"
    );
  });

  test("an editor mid-destruction's leaked listener does not act", function (assert) {
    const editor = buildEditor();
    detach = attachEditorShortcuts(editor);

    editor.isDestroying = true;

    pressDelete();

    assert.deepEqual(
      editor.removed,
      [],
      "the tearing-down editor's handler bailed"
    );
  });
});
