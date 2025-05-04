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

      // attrs may override match or start
      const {
        match: attrsMatch,
        start: attrsStart,
        ...markAttrs
      } = attrs ?? {};
      match = attrsMatch ?? match;
      start += attrsStart ?? 0;

      if (match[1]) {
        let textStart = start + match[0].indexOf(match[1]);
        let textEnd = textStart + match[1].length;
        if (textEnd < end) {
          tr.delete(textEnd, end);
        }
        if (textStart > start) {
          tr.delete(start, textStart);
        }

        tr.addMark(start, start + match[1].length, markType.create(markAttrs));
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

// from https://github.com/ProseMirror/prosemirror-commands/blob/master/src/commands.ts
export function atBlockStart(state, view) {
  let { $cursor } = state.selection;
  if (
    !$cursor ||
    (view ? !view.endOfTextblock("backward", state) : $cursor.parentOffset > 0)
  ) {
    return null;
  }
  return $cursor;
}

// https://github.com/discourse/discourse/pull/31933#discussion_r2019739410
export function changedDescendants(old, cur, f, offset = 0) {
  const oldSize = old.childCount,
    curSize = cur.childCount;
  outer: for (let i = 0, j = 0; i < curSize; i++) {
    const child = cur.child(i);
    for (let scan = j, e = Math.min(oldSize, i + 5); scan < e; scan++) {
      if (old.child(scan) === child) {
        j = scan + 1;
        offset += child.nodeSize;
        continue outer;
      }
    }
    f(child, offset);
    if (j < oldSize && old.child(j).sameMarkup(child)) {
      changedDescendants(old.child(j), child, f, offset + 1);
    } else {
      child.nodesBetween(0, child.content.size, f, offset + 1);
    }
    offset += child.nodeSize;
  }
}
