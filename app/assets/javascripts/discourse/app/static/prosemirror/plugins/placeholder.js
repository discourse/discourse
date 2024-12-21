import { Plugin } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";

const isEmptyParagraph = (node) => {
  return node.type.name === "paragraph" && node.nodeSize === 2;
};

export default () => {
  let placeholder;

  return new Plugin({
    view(view) {
      // TODO still wip
      placeholder = view.props.getContext().placeholder;
      return {
        update() {
          placeholder = view.props.getContext().placeholder;
        },
      };
    },
    props: {
      decorations(state) {
        console.log(placeholder);
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
