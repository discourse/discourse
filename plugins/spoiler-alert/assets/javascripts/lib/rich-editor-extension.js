const INLINE_NODES = ["inline_spoiler", "spoiler"];

export default {
  nodeSpec: {
    spoiler: {
      attrs: { blurred: { default: true } },
      group: "block",
      content: "block+",
      defining: true,
      parseDOM: [{ tag: "div.spoiled" }],
      toDOM: (node) => [
        "div",
        { class: `spoiled ${node.attrs.blurred ? "spoiler-blurred" : ""}` },
        0,
      ],
    },
    inline_spoiler: {
      attrs: { blurred: { default: true } },
      group: "inline",
      inline: true,
      content: "inline*",
      parseDOM: [{ tag: "span.spoiled" }],
      toDOM: (node) => [
        "span",
        { class: `spoiled ${node.attrs.blurred ? "spoiler-blurred" : ""}` },
        0,
      ],
    },
  },
  parse: {
    bbcode_spoiler: { block: "inline_spoiler" },
    wrap_bbcode(state, token) {
      if (token.nesting === 1 && token.attrGet("class") === "spoiler") {
        state.openNode(state.schema.nodes.spoiler);
      } else if (token.nesting === -1) {
        state.closeNode();
      }
    },
  },
  serializeNode: {
    spoiler(state, node) {
      state.write("[spoiler]\n");
      state.renderContent(node);
      state.write("[/spoiler]\n\n");
    },
    inline_spoiler(state, node) {
      state.write("[spoiler]");
      state.renderInline(node);
      state.write("[/spoiler]");
    },
  },
  plugins: {
    props: {
      handleClickOn(view, pos, node, nodePos, event, direct) {
        if (INLINE_NODES.includes(node.type.name)) {
          view.dispatch(
            view.state.tr.setNodeMarkup(nodePos, null, {
              blurred: !node.attrs.blurred,
            })
          );
          return true;
        }
      },
    },
  },
};
