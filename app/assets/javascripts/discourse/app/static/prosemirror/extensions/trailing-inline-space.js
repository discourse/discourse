/** @type {RichEditorExtension} */
const extension = {
  plugins: ({
    pmState: { Plugin, PluginKey },
    utils: { changedDescendants },
  }) =>
    new Plugin({
      key: new PluginKey("trailingInlineSpace"),

      appendTransaction(transactions, oldState, newState) {
        const tr = newState.tr;
        let modified = false;

        changedDescendants(oldState.doc, newState.doc, (node, pos) => {
          if (node.isBlock && node.inlineContent && node.childCount > 0) {
            const lastChild = node.lastChild;

            if (
              lastChild &&
              lastChild.isInline &&
              !lastChild.isText &&
              // can contain children
              lastChild.type.spec.content
            ) {
              tr.insert(pos + node.nodeSize - 1, newState.schema.text(" "));
              modified = true;
            }
          }
        });

        return modified ? tr : null;
      },
    }),
};

export default extension;
