import { waitForPromise } from "@ember/test-waiters";

/**
 * Lazily loads the ProseMirror modules needed to mount a constrained
 * inline-rich-text editor (no toolbar, no surrounding composer UI). Returns
 * an object with the imported symbols ready to plug into an `EditorView`.
 *
 * Mirrors `loadRichEditor` (`discourse/lib/load-rich-editor`) but exposes
 * the raw building blocks rather than a pre-built component. Used by
 * inline-edit controllers that need ProseMirror without the full composer
 * (e.g. edit-driven tooling mounting an inline editor inside a block's
 * edit form);
 * safe to use from plugin code because the dynamic `import()` calls
 * resolve through core's bundler,
 * which has access to the `prosemirror-*` packages and the
 * `discourse/static/prosemirror/*` chunks (plugins can't statically
 * import either set).
 */
export default async function loadInlineRichEditor() {
  const [
    pmCommands,
    pmHistory,
    pmKeymap,
    pmModel,
    pmState,
    pmView,
    schemaModule,
  ] = await waitForPromise(
    Promise.all([
      import("prosemirror-commands"),
      import("prosemirror-history"),
      import("prosemirror-keymap"),
      import("prosemirror-model"),
      import("prosemirror-state"),
      import("prosemirror-view"),
      import("discourse/static/prosemirror/core/schema"),
    ])
  );

  return {
    toggleMark: pmCommands.toggleMark,
    history: pmHistory.history,
    undo: pmHistory.undo,
    redo: pmHistory.redo,
    keymap: pmKeymap.keymap,
    Node: pmModel.Node,
    EditorState: pmState.EditorState,
    TextSelection: pmState.TextSelection,
    EditorView: pmView.EditorView,
    createSchema: schemaModule.createSchema,
  };
}
