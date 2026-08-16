/**
 * The source of a block that is shown rendered, held by a node view that
 * previews it (see `discourse/components/composer/preview-node-view`).
 *
 * It behaves like a code block without being one: the language belongs to the
 * feature rather than the author, so there is no language picker, and it never
 * serializes on its own — the feature wrapping it writes its own markup.
 *
 * @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension}
 */
const extension = {
  nodeSpec: {
    preview_source: {
      attrs: { params: { default: "" } },
      content: "text*",
      code: true,
      defining: true,
      marks: "",
      parseDOM: [{ tag: "pre.preview-source", preserveWhitespace: "full" }],
      toDOM: () => ["pre", { class: "preview-source" }, ["code", 0]],
    },
  },

  serializeNode: {
    preview_source: (state, node) => {
      state.text(node.textContent, false);
    },
  },
};

export default extension;
