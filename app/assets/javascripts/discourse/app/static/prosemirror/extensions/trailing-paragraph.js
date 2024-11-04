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
          return state.doc.lastChild.type !== state.schema.nodes.paragraph;
        },
        apply(tr, value) {
          if (!tr.docChanged) {
            return value;
          }

          return tr.doc.lastChild.type !== tr.doc.type.schema.nodes.paragraph;
        },
      },
    });
  },
};
