/** @type {RichEditorExtension} */
const extension = {
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
      parseDOM: [{ tag: "pre.html-block", preserveWhitespace: "full" }],
      toDOM() {
        return ["pre", { class: "html-block" }, ["code", 0]];
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
      state.text(node.textContent, false);
      state.write("\n\n");
    },
  },
  plugins: ({ pmState: { Plugin }, utils: { changedDescendants } }) =>
    // When cooking the markdown, a html block is auto-closed when a \n\n
    // is found, so here we make sure there's at most one \n in the block
    new Plugin({
      appendTransaction(transactions, prevState, state) {
        if (!transactions.some((tr) => tr.docChanged)) {
          return null;
        }

        const { tr } = state;
        changedDescendants(prevState.doc, state.doc, (node, pos) => {
          if (node.type.name === "html_block") {
            const content = node.textContent;
            const normalized = content.replace(/\n{2,}/g, "\n");

            if (content !== normalized) {
              const textNode = node.content.firstChild;
              tr.replaceWith(
                pos + 1,
                pos + 1 + textNode.nodeSize,
                state.schema.text(normalized)
              );
            }
          }
        });

        return tr;
      },
    }),
};

export default extension;
