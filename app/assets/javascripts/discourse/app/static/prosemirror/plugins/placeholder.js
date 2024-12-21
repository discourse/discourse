import { Plugin } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";

const isEmptyParagraph = (node) => {
  return node.type.name === "paragraph" && node.nodeSize === 2;
};

export default () => {
  let placeholder;

  return new Plugin({
    view(view) {
      placeholder = view.props.getContext().placeholder;
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
};
