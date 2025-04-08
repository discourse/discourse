import { InputRule } from "prosemirror-inputrules";
import { StepMap } from "prosemirror-transform";

export { getLinkify, isBoundary, isWhiteSpace } from "../lib/markdown-it";

export { buildBBCodeAttrs } from "discourse/lib/text";

// https://discuss.prosemirror.net/t/input-rules-for-wrapping-marks/537
export function markInputRule(regexp, markType, getAttrs) {
  return new InputRule(
    regexp,
    (state, match, start, end) => {
      const attrs = getAttrs instanceof Function ? getAttrs(match) : getAttrs;
      const tr = state.tr;

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
    },
    { inCodeMark: false }
  );
}

export function getChangedRanges(tr) {
  const { steps, mapping } = tr;
  const changes = [];

  mapping.maps.forEach((stepMap, index) => {
    const ranges = [];

    if (stepMap === StepMap.empty) {
      if (steps[index].from === undefined || steps[index].to === undefined) {
        return;
      }

      ranges.push(steps[index]);
    } else {
      stepMap.forEach((from, to) => ranges.push({ from, to }));
    }

    ranges.forEach(({ from, to }) => {
      const change = { new: {}, old: {} };
      change.new.from = mapping.slice(index).map(from, -1);
      change.new.to = mapping.slice(index).map(to);
      change.old.from = mapping.invert().map(change.new.from, -1);
      change.old.to = mapping.invert().map(change.new.to);

      changes.push(change);
    });
  });

  return changes;
}
