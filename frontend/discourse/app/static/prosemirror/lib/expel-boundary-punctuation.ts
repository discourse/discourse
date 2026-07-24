import {
  type Fragment,
  type MarkType,
  Node,
  type Slice,
} from "prosemirror-model";
import { Transform } from "prosemirror-transform";

const FLANKING_SENSITIVE_MARKS = ["strong", "em", "strikethrough"];

// Matches markdown-it's `isPunctChar` (P || S).
const PUNCTUATION = /[\p{P}\p{S}]/u;
const LEADING_PUNCTUATION = new RegExp(`^${PUNCTUATION.source}+`, "u");
const TRAILING_PUNCTUATION = new RegExp(`${PUNCTUATION.source}+$`, "u");

function isWordChar(char: string | undefined): boolean {
  return !!char && !PUNCTUATION.test(char) && !/\s/u.test(char);
}

// Punctuation counterpart to prosemirror-markdown's `expelEnclosingWhitespace`:
// `**text.**text` reparses as literal, so serialize as `**text**.text` instead.
// Slices/fragments from selection serialization pass through untouched.
export default function expelBoundaryPunctuation(
  content: Node | Slice | Fragment
): Node | Slice | Fragment {
  if (!(content instanceof Node)) {
    return content;
  }

  const tr = new Transform(content);
  const markTypes = FLANKING_SENSITIVE_MARKS.map(
    (name) => content.type.schema.marks[name]
  ).filter((markType): markType is MarkType => Boolean(markType));

  // RemoveMarkStep doesn't shift positions, so no mapping is needed.
  content.descendants((node, pos) => {
    if (!node.isTextblock) {
      return;
    }

    node.forEach((child, offset, index) => {
      const text = child.text;
      if (text === undefined) {
        return;
      }

      const start = pos + 1 + offset;
      const end = start + text.length;
      const next = index + 1 < node.childCount ? node.child(index + 1) : null;
      const prev = index > 0 ? node.child(index - 1) : null;
      const nextChar = next?.text?.[0];
      const prevText = prev?.text;
      const prevChar = prevText?.[prevText.length - 1];

      for (const markType of markTypes) {
        if (!markType.isInSet(child.marks)) {
          continue;
        }

        if ((!next || !markType.isInSet(next.marks)) && isWordChar(nextChar)) {
          const trailing = text.match(TRAILING_PUNCTUATION);
          if (trailing) {
            tr.removeMark(end - trailing[0].length, end, markType);
          }
        }

        if ((!prev || !markType.isInSet(prev.marks)) && isWordChar(prevChar)) {
          const leading = text.match(LEADING_PUNCTUATION);
          if (leading) {
            tr.removeMark(start, start + leading[0].length, markType);
          }
        }
      }
    });
  });

  return tr.doc;
}
