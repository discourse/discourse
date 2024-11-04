import { Plugin } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";

const isEmptyParagraph = (node) => {
  return node.type.name === "paragraph" && node.nodeSize === 2;
};

export default (placeholder) => {
  return new Plugin({
    props: {
      decorations(state) {
        const { $from } = state.selection;

        if (
          state.doc.childCount === 1 &&
          state.doc.firstChild === $from.parent &&
          isEmptyParagraph($from.parent)
        ) {
          const decoration = Decoration.node($from.before(), $from.after(), {
            "data-placeholder": placeholder,
          });
          return DecorationSet.create(state.doc, [decoration]);
        }
      },
    },
  });
};
