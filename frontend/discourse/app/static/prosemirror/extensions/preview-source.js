/**
 * The source of a block shown rendered by `composer/preview-node-view`.
 * Highlighted like a code block, but the language belongs to the feature
 * rather than the author, so there is no language picker.
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
      // clicks resolve to the block around it, which is the unit to select
      selectable: false,
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
