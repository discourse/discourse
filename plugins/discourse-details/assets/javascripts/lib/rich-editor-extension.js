export default {
  nodeSpec: {
    details: {
      content: "summary block+",
      group: "block",
      defining: true,
      parseDOM: [{ tag: "details" }],
      toDOM: () => ["details", { open: true }, 0],
    },
    summary: {
      content: "inline*",
      group: "block",
      parseDOM: [{ tag: "summary" }],
      toDOM: () => ["summary", 0],
    },
  },
  parse: {
    bbcode(state, token) {
      if (token.tag === "details") {
        state.openNode(state.schema.nodes.details);
        return true;
      }

      if (token.tag === "summary") {
        state.openNode(state.schema.nodes.summary);
        return true;
      }
    },
  },
  serializeNode: {
    details(state, node) {
      state.renderContent(node);
      state.write("[/details]\n");
    },
    summary(state, node) {
      state.write("[details=");
      state.renderContent(node);
      state.write("]\n");
    },
  },
};
