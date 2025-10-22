import { InputRule } from "prosemirror-inputrules";
import { StepMap } from "prosemirror-transform";

export { getLinkify, isBoundary, isWhiteSpace } from "../lib/markdown-it";

export { buildBBCodeAttrs } from "discourse/lib/text";

/**
 * Creates an InputRule that applies a mark based on a regex pattern.
 *
 * Makes assumptions about having a single matching group, which can be rewritten with getAttrs
 *
 * Initially from https://discuss.prosemirror.net/t/input-rules-for-wrapping-marks/537
 *
 * For usage examples,
 * @see discourse/app/static/prosemirror/core/inputrules.js
 *
 * @param {RegExp} regexp
 * @param {import("prosemirror-model").MarkType} markType
 * @param {Function} getAttrs
 *
 * @returns {import("prosemirror-inputrules").InputRule}
 */
export function markInputRule(regexp, markType, getAttrs) {
  return new InputRule(regexp, (state, match, start, end) => {
    const attrs = getAttrs instanceof Function ? getAttrs(match) : getAttrs;
    const tr = state.tr;

    // attrs may override match or start
    const { match: attrsMatch, start: attrsStart, ...markAttrs } = attrs ?? {};

    match = attrsMatch ?? match;
    start = start + (attrsStart ?? 0);

    if (match[1]) {
      const fullMatch = match[0];
      const capturedContent = match[1];
      const contentStart = fullMatch.indexOf(capturedContent);
      const contentEnd = contentStart + capturedContent.length;

      const ranges = [];
      if (contentStart > 0) {
        ranges.push([start, start + contentStart]);
      }
      if (contentEnd < fullMatch.length) {
        ranges.push([start + contentEnd, start + fullMatch.length]);
      }

      for (const [rangeStart, rangeEnd] of ranges) {
        let hasCodeMark = false;
        state.doc.nodesBetween(rangeStart, rangeEnd, (node) => {
          if (node.isInline && node.marks.some((m) => m.type.spec.code)) {
            hasCodeMark = true;
            return false;
          }
        });
        if (hasCodeMark) {
          return null;
        }
      }
    }

    if (match[1]) {
      const textStart = start + match[0].indexOf(match[1]);
      const textEnd = textStart + match[1].length;
      if (textEnd < end) {
        tr.delete(textEnd, end);
      }
      if (textStart > start) {
        tr.delete(start, textStart);
      }

      tr.addMark(start, start + match[1].length, markType.create(markAttrs));
      tr.setStoredMarks(tr.doc.resolve(start + match[1].length + 1).marks());
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
  });
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

// Check if a mark of a specific type is present in the current selection,
// with optional scoping by specific attributes.
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

// Check if a node of a specific type is present in the current selection,
// with optional scoping by specific attributes.
export function inNode(state, nodeType, attrs = {}) {
  const { $from } = state.selection;

  for (let depth = $from.depth; depth >= 0; depth--) {
    const node = $from.node(depth);
    if (node.type === nodeType) {
      if (!Object.keys(attrs).length) {
        return true;
      }

      return Object.keys(attrs).every((key) => node.attrs[key] === attrs[key]);
    }
  }

  return false;
}

// Check if a node of a specific type is active in the current selection,
// (with optional scoping by specific attributes), and that no other nodes
// of any other type are present in the selection.
export function isNodeActive(state, nodeType, attrs = {}) {
  const { from, to, empty } = state.selection;
  const nodeRanges = [];

  // Get all the nodes in the selection range and their positions.
  state.doc.nodesBetween(from, to, (node, pos) => {
    if (node.isText) {
      return;
    }

    const relativeFrom = Math.max(from, pos);
    const relativeTo = Math.min(to, pos + node.nodeSize);

    nodeRanges.push({
      node,
      from: relativeFrom,
      to: relativeTo,
    });
  });

  const selectionRange = to - from;

  // Find nodes that match the provided type and attributes.
  const matchedNodeRanges = nodeRanges
    .filter((nodeRange) => {
      return nodeType.name === nodeRange.node.type.name;
    })
    .filter((nodeRange) => {
      if (!Object.keys(attrs).length) {
        return true;
      } else {
        return Object.keys(attrs).every(
          (key) => nodeRange.node.attrs[key] === attrs[key]
        );
      }
    });

  if (empty) {
    return !!matchedNodeRanges.length;
  }

  // Determines if there are other nodes not matching nodeType in the selection
  // by summing selection ranges to find "gaps" in the selection.
  const range = matchedNodeRanges.reduce(
    (sum, nodeRange) => sum + nodeRange.to - nodeRange.from,
    0
  );

  // If there are no "gaps" in the selection, it means the nodeType is active
  // with no other node types selected.
  return range >= selectionRange;
}
