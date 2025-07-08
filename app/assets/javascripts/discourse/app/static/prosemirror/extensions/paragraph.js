/** @type {RichEditorExtension} */
const extension = {
  parse: {
    paragraph_open(state, token, tokens, i) {
      if (i > 0 && tokens[i - 1].type === "paragraph_close") {
        state.openNode(state.schema.nodes.paragraph);
        state.closeNode();
      }

      state.openNode(state.schema.nodes.paragraph);
    },
    paragraph_close(state) {
      state.closeNode();
    },
  },
  serializeNode: {
    paragraph(state, node, parent, index) {
      const out = state.out;
      state.renderInline(node);

      const text = state.out.substring(out.length);

      let prevNode = index && parent.child(index - 1);
      if (prevNode?.type?.name === "paragraph" && prevNode.content.size !== 0) {
        if (state.delim) {
          state.out =
            out + text.replace(new RegExp(`^\n${state.delim.trim()}`), "");
        } else {
          state.out = out + text.replace(/^\n\n/, "\n");
        }
      }

      state.closeBlock(node);
    },
  },
};

export default extension;
