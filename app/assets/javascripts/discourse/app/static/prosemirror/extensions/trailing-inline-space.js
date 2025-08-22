import { splitBlock } from "prosemirror-commands";
import { TextSelection } from "prosemirror-state";

function isInlineContainer(node) {
  return (
    node.isInline &&
    !node.isText &&
    node.type?.spec?.content &&
    !node.type?.spec?.atom
  );
}

function findInlineContainerDepth($from) {
  for (let depth = $from.depth; depth > 0; depth--) {
    if (isInlineContainer($from.node(depth))) {
      return depth;
    }
  }
  return null;
}

/** @type {RichEditorExtension} */
const extension = {
  keymap: () => ({
    Enter: (state, dispatch) => {
      const selection = state.selection;
      if (!(selection instanceof TextSelection)) {
        return false;
      }

      const initialDepth = findInlineContainerDepth(selection.$from);
      if (!dispatch) {
        return selection.empty ? initialDepth !== null : true;
      }
      if (selection.empty && initialDepth === null) {
        return false;
      }

      const tr = state.tr;
      if (!selection.empty) {
        tr.delete(selection.from, selection.to);
      }

      const basePos = selection.empty ? selection.$from.pos : selection.from;
      const mappedBasePos = tr.mapping.map(basePos, -1);
      let $from = tr.doc.resolve(mappedBasePos);
      const depth = findInlineContainerDepth($from);
      if (depth === null) {
        if (tr.steps.length) {
          dispatch(tr);
        }
        return splitBlock(tr.steps.length ? state.apply(tr) : state, dispatch);
      }

      const atStart = $from.pos === $from.start(depth);
      const atEnd = $from.pos === $from.end(depth);

      if (atStart) {
        const pos = $from.before(depth);
        tr.setSelection(TextSelection.create(tr.doc, pos));
        dispatch(tr);
        return splitBlock(state.apply(tr), dispatch);
      }

      if (atEnd) {
        let pos = $from.after(depth);
        const next = tr.doc.resolve(pos).nodeAfter;
        if (next?.isText && next.text?.[0] === " ") {
          pos += 1;
        }
        tr.setSelection(TextSelection.create(tr.doc, pos));
        dispatch(tr);
        return splitBlock(state.apply(tr), dispatch);
      }

      const fromPos = $from.pos;
      const containerEnd = $from.end(depth);
      const rightSlice = tr.doc.slice(fromPos, containerEnd);

      tr.delete(fromPos, containerEnd);
      $from = tr.doc.resolve(fromPos);
      const outsidePos = $from.after(depth);
      if (rightSlice.content.size) {
        tr.insert(outsidePos, rightSlice.content);
      }
      tr.setSelection(TextSelection.create(tr.doc, outsidePos));
      dispatch(tr);
      return splitBlock(state.apply(tr), dispatch);
    },
  }),
  plugins: ({
    pmState: { Plugin, PluginKey },
    utils: { changedDescendants },
  }) =>
    new Plugin({
      key: new PluginKey("trailingInlineSpace"),

      appendTransaction(transactions, oldState, newState) {
        const tr = newState.tr;

        changedDescendants(oldState.doc, newState.doc, (node, pos) => {
          if (!node.isBlock || !node.inlineContent || node.childCount === 0) {
            return;
          }
          const lastChild = node.lastChild;
          if (lastChild && isInlineContainer(lastChild)) {
            tr.insert(pos + node.nodeSize - 1, newState.schema.text(" "));
          }
        });

        return tr.steps.length ? tr : null;
      },
    }),
};

export default extension;
