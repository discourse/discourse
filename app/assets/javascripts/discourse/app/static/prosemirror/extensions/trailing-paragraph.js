export default {
  plugins({ Plugin, PluginKey }) {
    const plugin = new PluginKey("trailing-paragraph");

    return new Plugin({
      key: plugin,
      appendTransaction(_, __, state) {
        if (!plugin.getState(state)) {
          return;
        }

        return state.tr.insert(
          state.doc.content.size,
          state.schema.nodes.paragraph.create()
        );
      },
      state: {
        init(_, state) {
          return !isLastChildEmptyParagraph(state);
        },
        apply(tr, value) {
          if (!tr.docChanged) {
            return value;
          }

          return !isLastChildEmptyParagraph(tr);
        },
      },
    });
  },
};

function isLastChildEmptyParagraph(state) {
  const { doc } = state;
  const lastChild = doc.lastChild;

  return (
    lastChild.type.name === "paragraph" &&
    lastChild.nodeSize === 2 &&
    lastChild.content.size === 0
  );
}
