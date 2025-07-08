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

/**
 * Get the continuous range of a mark at a given position.
 *
 * @param $pos
 *    {import("prosemirror-model").ResolvedPos} - The position in the document.
 * @param type
 *    {import("prosemirror-model").MarkType} - The type of mark to find.
 * @param attrs
 *    {Object} - Optional attributes to match against the mark.
 * @returns {{ from: number, to: number, mark: import("prosemirror-model").Mark } | undefined}
 */
export function getMarkRange($pos, type, attrs = {}) {
  if (!$pos || !type) {
    return;
  }

  // Try node after, then before, return if neither has the mark
  let start = $pos.parent.childAfter($pos.parentOffset);
  if (!start.node || !findMarkOfType(start.node.marks, type, attrs)) {
    start = $pos.parent.childBefore($pos.parentOffset);
    if (!start.node || !findMarkOfType(start.node.marks, type, attrs)) {
      return;
    }
  }

  const mark = findMarkOfType(start.node.marks, type, attrs);

  let from = $pos.start() + start.offset;
  let to = from + start.node.nodeSize;

  // Expand backward
  let { index } = start;
  while (
    index > 0 &&
    findMarkOfType($pos.parent.child(index - 1).marks, type, mark.attrs)
  ) {
    index--;
    from -= $pos.parent.child(index).nodeSize;
  }

  // Expand forward
  index = start.index + 1;
  while (
    index < $pos.parent.childCount &&
    findMarkOfType($pos.parent.child(index).marks, type, mark.attrs)
  ) {
    to += $pos.parent.child(index).nodeSize;
    index++;
  }

  return { from, to, mark };
}

/**
 * Find a mark of a specific type within marks, matching the attributes if provided.
 *
 * @param marks
 *    {import("prosemirror-model").Mark[]} - Array of marks to search through.
 * @param type
 *   {import("prosemirror-model").MarkType} - The type of mark to find.
 * @param attrs
 *  {Object} - Optional attributes to match against the mark.
 * @returns {import("prosemirror-model").Mark | undefined}
 */
export function findMarkOfType(marks, type, attrs = {}) {
  return marks.find(
    (item) =>
      item.type === type &&
      Object.keys(attrs).every((key) => item.attrs[key] === attrs[key])
  );
}

export function hasMark(state, markType, attrs = {}) {
  const { from, to, empty } = state.selection;

  // For empty selection, check stored marks or marks at position
  if (empty) {
    const storedMarks = state.storedMarks || state.selection.$from.marks();
    return !!findMarkOfType(storedMarks, markType, attrs);
  }

  // For range selections, check if mark exists in the range
  return (
    state.doc.rangeHasMark(from, to, markType) &&
    (!Object.keys(attrs).length ||
      state.doc.rangeHasMark(from, to, markType.create(attrs)))
  );
}

export function inNode(state, nodeType, attrs = {}) {
  const { $from } = state.selection;

  for (let d = $from.depth; d >= 0; d--) {
    const node = $from.node(d);
    if (node.type === nodeType) {
      if (!Object.keys(attrs).length) {
        return true;
      }

      return Object.keys(attrs).every((key) => node.attrs[key] === attrs[key]);
    }
  }

  return false;
}
