/** @type {RichEditorExtension} */
const extension = {
  plugins({ pmState: { Plugin, PluginKey } }) {
    const plugin = new PluginKey("trailing-paragraph");

    return new Plugin({
      key: plugin,
      appendTransaction(_, __, state) {
        if (!plugin.getState(state)) {
          return;
        }

        return state.tr
          .setMeta("addToHistory", false)
          .insert(
            state.doc.content.size,
            state.schema.nodes.paragraph.create()
          );
      },
      state: {
        init(_, state) {
          return !isLastChildParagraph(state);
        },
        apply(tr, value) {
          if (!tr.docChanged) {
            return value;
          }

          return !isLastChildParagraph(tr);
        },
      },
    });
  },
};

function isLastChildParagraph(state) {
  const { doc } = state;
  const lastChild = doc.lastChild;

  return lastChild.type.name === "paragraph";
}

export default extension;
