import { InputRule } from "prosemirror-inputrules";

export { getLinkify, isBoundary, isWhiteSpace } from "../lib/markdown-it";

// https://discuss.prosemirror.net/t/input-rules-for-wrapping-marks/537
export function markInputRule(regexp, markType, getAttrs) {
  return new InputRule(
    regexp,
    (state, match, start, end) => {
      const attrs = getAttrs instanceof Function ? getAttrs(match) : getAttrs;
      const tr = state.tr;

      const { prefix = "", matchIndex = 1, ...markAttrs } = attrs ?? {};

      if (state.doc.rangeHasMark(start, end, markType)) {
        return null;
      }

      if (match[matchIndex]) {
        let textStart = start + match[0].indexOf(match[matchIndex]);
        let textEnd = textStart + match[matchIndex].length;
        if (textEnd < end) {
          tr.delete(textEnd, end);
        }
        if (textStart > start + prefix.length) {
          tr.delete(start + prefix.length, textStart);
        }
        end = start + match[matchIndex].length;

        tr.addMark(start, end, markType.create(markAttrs));
        tr.removeStoredMark(markType);
      } else {
        tr.delete(start, end);
        tr.insertText(" ");
        tr.addMark(start, start + 1, markType.create(markAttrs));
        tr.removeStoredMark(markType);
        tr.insertText(" ");

        tr.setSelection(
          state.selection.constructor.create(tr.doc, start, start + 1)
        );
      }

      return tr;
    },
    { inCodeMark: false }
  );
}
