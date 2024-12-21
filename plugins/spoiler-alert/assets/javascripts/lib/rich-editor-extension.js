const SPOILER_NODES = ["inline_spoiler", "spoiler"];

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    spoiler: {
      attrs: { blurred: { default: true } },
      group: "block",
      content: "block+",
      parseDOM: [{ tag: "div.spoiled" }],
      toDOM: () => ["div", { class: "spoiled" }, 0],
    },
    inline_spoiler: {
      attrs: { blurred: { default: true } },
      group: "inline",
      inline: true,
      content: "inline*",
      parseDOM: [{ tag: "span.spoiled" }],
      toDOM: () => ["span", { class: "spoiled" }, 0],
    },
  },
  parse: {
    bbcode_spoiler: { block: "inline_spoiler" },
    wrap_bbcode(state, token) {
      if (token.nesting === 1 && token.attrGet("class") === "spoiler") {
        state.openNode(state.schema.nodes.spoiler);
        return true;
      } else if (token.nesting === -1 && state.top().type.name === "spoiler") {
        state.closeNode();
        return true;
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
  plugins({ pmState: { Plugin }, pmView: { Decoration, DecorationSet } }) {
    return new Plugin({
      props: {
        decorations(state) {
          return this.getState(state);
        },
        handleClickOn(view, pos, node, nodePos) {
          if (SPOILER_NODES.includes(node.type.name)) {
            const decoSet = this.getState(view.state) || DecorationSet.empty;

            const isBlurred =
              decoSet.find(nodePos, nodePos + node.nodeSize).length > 0;

            const newDeco = isBlurred
              ? decoSet.remove(decoSet.find(nodePos, nodePos + node.nodeSize))
              : decoSet.add(view.state.doc, [
                  Decoration.node(nodePos, nodePos + node.nodeSize, {
                    class: "spoiler-blurred",
                  }),
                ]);

            view.dispatch(view.state.tr.setMeta(this, newDeco));
            return true;
          }
        },
      },
      state: {
        init() {
          return DecorationSet.empty;
        },
        apply(tr, set) {
          return tr.getMeta(this) || set.map(tr.mapping, tr.doc);
        },
      },
    });
  },
};

export default extension;
