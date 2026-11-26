// Parts are adapted from @codemirror/lang-liquid 6.3.3,
// Copyright (C) 2018-2023 by Marijn Haverbeke and others, MIT License; see
// LICENSE.

import { liquidLanguage } from "@codemirror/lang-liquid";
import { Language, syntaxTree } from "@codemirror/language";
import { EditorState, Prec } from "@codemirror/state";
import { parseMixed, Parser } from "@lezer/common";

// Liquid has no line comments outside a tag, so a line is commented with a
// block; an HTML comment would still run the Liquid in it.
export const LIQUID_COMMENT = {
  block: { open: "{% comment %}", close: "{% endcomment %}" },
};

function liquidTagAt(state, pos, side) {
  for (
    let node = syntaxTree(state).resolve(pos, side);
    node;
    node = node.parent
  ) {
    if (node.name === "Tag" && node.getChild("liquid")) {
      return node;
    }
  }
  return null;
}

// Each line of `{% liquid %}` is a statement, which `#` comments out. The
// lines with the tag's own delimiters break if commented on their own, so
// they are only commented along with the whole tag, as a block.
export const liquidStatementComments = Prec.highest(
  EditorState.languageData.of((state, pos, side) => {
    const tag = liquidTagAt(state, pos, side);
    if (!tag) {
      return [];
    }

    const { doc } = state;
    const first = doc.lineAt(tag.from).number;
    const last = doc.lineAt(tag.to).number;
    const range = state.selection.ranges.find(
      ({ from, to }) => doc.lineAt(from).from <= pos && pos <= doc.lineAt(to).to
    ) ?? { from: pos, to: pos };
    const start = doc.lineAt(range.from).number;
    const end = doc.lineAt(range.to).number;

    if (start <= first && end >= last) {
      return [];
    }
    if (start > first && end < last) {
      return [{ commentTokens: { line: "#" } }];
    }
    return [{ commentTokens: {} }];
  })
);

// The parser doesn't read whitespace control, so it sees each trim dash as a
// space. Swapping one character for one keeps every offset in the document.
const TRIM_MARKERS = /\{\{-|\{%-|-\}\}|-%\}/g;

function blankDash(marker) {
  return marker.startsWith("-")
    ? ` ${marker.slice(1)}`
    : `${marker.slice(0, 2)} `;
}

class TrimInput {
  #input;

  constructor(input) {
    this.#input = input;
    this.length = input.length;
    this.lineChunks = input.lineChunks;
  }

  read(from, to) {
    // Two characters either side catch a marker that the range splits.
    const start = Math.max(0, from - 2);
    const end = Math.min(this.length, to + 2);
    return this.#input
      .read(start, end)
      .replace(TRIM_MARKERS, blankDash)
      .slice(from - start, to - start);
  }

  chunk(from) {
    const text = this.#input.chunk(from);
    return text.includes("-") ? this.read(from, from + text.length) : text;
  }
}

class TrimParser extends Parser {
  #inner;

  constructor(inner) {
    super();
    this.#inner = inner;
  }

  createParse(input, fragments, ranges) {
    return this.#inner.createParse(new TrimInput(input), fragments, ranges);
  }
}

/** Liquid tags over `base`, which parses the text between them. */
export function liquidOver(base) {
  const language = liquidLanguage.configure(
    {
      wrap: parseMixed((node) =>
        node.type.isTop
          ? {
              parser: base.parser,
              overlay: (n) => n.name === "Text" || n.name === "RawText",
            }
          : null
      ),
    },
    "liquid"
  );

  return new Language(
    language.data,
    new TrimParser(language.parser),
    [],
    language.name
  );
}
