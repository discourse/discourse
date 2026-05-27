/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    details: {
      attrs: { open: { default: true } },
      content: "summary block+",
      group: "block",
      selectable: true,
      defining: true,
      isolating: true,
      parseDOM: [{ tag: "details" }],
      toDOM: (node) => ["details", { open: node.attrs.open || undefined }, 0],
    },
    summary: {
      content: "inline*",
      parseDOM: [{ tag: "summary" }],
      toDOM: () => ["summary", 0],
    },
  },
  parse: {
    bbcode_open(state, token) {
      if (token.tag === "details") {
        state.openNode(state.schema.nodes.details);
        return true;
      }

      if (token.tag === "summary") {
        state.openNode(state.schema.nodes.summary);
        return true;
      }
    },
    bbcode_close(state, token) {
      if (token.tag === "details" || token.tag === "summary") {
        state.closeNode();
        return true;
      }
    },
  },
  serializeNode: {
    details(state, node) {
      state.renderContent(node);
      state.write("[/details]\n\n");
    },
    summary(state, node) {
      let hasSummary = false;
      // If the [details] tag has no summary.
      if (node.content.childCount === 0) {
        state.write("[details");
      } else {
        hasSummary = true;
        state.write('[details="');
        node.content.forEach(
          (child) =>
            child.text &&
            state.text(child.text.replace(/"/g, "“"), state.inAutolink)
        );
      }
      let finalState = "]\n";
      if (hasSummary) {
        finalState = `"${finalState}`;
      }
      state.write(finalState);
    },
  },
  plugins: {
    props: {
      handleClickOn(view, pos, node, nodePos) {
        // if the click position in the document is not the first within the summary node
        if (pos > nodePos + 1 || node.type.name !== "summary") {
          return false;
        }

        const details = view.state.doc.nodeAt(nodePos - 1);
        view.dispatch(
          view.state.tr.setNodeMarkup(nodePos - 1, null, {
            open: !details.attrs.open,
          })
        );
        return true;
      },
    },
  },
};

export default extension;
