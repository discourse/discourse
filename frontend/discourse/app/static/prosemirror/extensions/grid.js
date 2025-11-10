/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    grid: {
      content: "block+",
      group: "block",
      createGapCursor: true,
      parseDOM: [
        { tag: "div.d-image-grid" },
        { tag: "div.composer-image-grid" },
      ],
      toDOM() {
        return ["div", { class: "composer-image-grid" }, 0];
      },
    },
  },

  parse: {
    bbcode_open(state, token) {
      if (token.attrGet("class") === "d-image-grid") {
        state.openNode(state.schema.nodes.grid);
        return true;
      }
    },
    bbcode_close(state) {
      if (state.top().type.name === "grid") {
        state.closeNode();
        return true;
      }
    },
  },

  serializeNode: {
    grid: (state, node) => {
      state.write("\n[grid]\n\n");
      state.renderContent(node.content);
      state.write("\n[/grid]\n\n");
    },
  },

  inputRules: () => ({
    match: /\[grid]$/,
    handler: (state, match, start, end) => {
      const grid = state.schema.nodes.grid.createAndFill();
      if (grid) {
        return state.tr.replaceWith(start, end, grid);
      }
    },
  }),
};

export default extension;
