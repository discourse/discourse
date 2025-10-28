/**
 * This extension is considered a "core" extension, it's autoloaded by ProsemirrorEditor
 *
 * @type {RichEditorExtension}
 */
const extension = {
  plugins({
    pmState: { Plugin, PluginKey },
    pmView: { Decoration, DecorationSet },
    getContext,
  }) {
    let placeholder;

    return new Plugin({
      key: new PluginKey("placeholder"),
      view() {
        placeholder = getContext().placeholder;
        return {};
      },
      state: {
        init() {
          return placeholder;
        },
        apply(tr) {
          const contextChanged = tr.getMeta("discourseContextChanged");
          if (contextChanged?.key === "placeholder") {
            placeholder = contextChanged.value;
          }

          return placeholder;
        },
      },
      props: {
        decorations(state) {
          const { $head } = state.selection;

          if (
            state.doc.childCount === 1 &&
            state.doc.firstChild === $head.parent &&
            isEmptyParagraph($head.parent)
          ) {
            const decoration = Decoration.node($head.before(), $head.after(), {
              "data-placeholder": this.getState(state),
            });
            return DecorationSet.create(state.doc, [decoration]);
          }
        },
      },
    });
  },
};

function isEmptyParagraph(node) {
  return node.type.name === "paragraph" && node.nodeSize === 2;
}

export default extension;
