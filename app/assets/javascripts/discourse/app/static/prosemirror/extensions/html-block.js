export default {
  nodeSpec: {
    html_block: {
      attrs: { params: { default: "html" } },
      group: "block",
      content: "text*",
      code: true,
      defining: true,
      marks: "",
      isolating: true,
      selectable: true,
      draggable: true,
      parseDOM: [
        { tag: "pre.d-editor__html-block", preserveWhitespace: "full" },
      ],
      toDOM() {
        return ["pre", { class: "d-editor__html-block" }, ["code", 0]];
      },
    },
  },
  parse: {
    html_block: (state, token) => {
      state.openNode(state.schema.nodes.html_block);
      state.addText(token.content.trim());
      state.closeNode();
    },
  },
  serializeNode: {
    html_block: (state, node) => {
      state.renderContent(node);
      state.write("\n\n");
    },
  },
};
