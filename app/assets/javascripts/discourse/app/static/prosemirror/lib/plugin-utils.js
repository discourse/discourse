import { InputRule } from "prosemirror-inputrules";

export { getLinkify, isBoundary, isWhiteSpace } from "../lib/markdown-it";

// https://discuss.prosemirror.net/t/input-rules-for-wrapping-marks/537
export function markInputRule(regexp, markType, getAttrs) {
  return new InputRule(regexp, (state, match, start, end) => {
    const attrs = getAttrs instanceof Function ? getAttrs(match) : getAttrs;
    const tr = state.tr;

    if (
      state.doc.rangeHasMark(start, end, markType) ||
      state.doc.rangeHasMark(start, end, state.schema.marks.code)
    ) {
      return null;
    }

    if (match[1]) {
      let textStart = start + match[0].indexOf(match[1]);
      let textEnd = textStart + match[1].length;
      if (textEnd < end) {
        tr.delete(textEnd, end);
      }
      if (textStart > start) {
        tr.delete(start, textStart);
      }
      end = start + match[1].length;

      tr.addMark(start, end, markType.create(attrs));
      tr.removeStoredMark(markType);
    } else {
      tr.delete(start, end);
      tr.insertText(" ");
      tr.addMark(start, start + 1, markType.create(attrs));
      tr.removeStoredMark(markType);
      tr.insertText(" ");

      tr.setSelection(
        state.selection.constructor.create(tr.doc, start, start + 1)
      );
    }

    return tr;
  });
}
