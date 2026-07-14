import { helperContext } from "discourse/lib/helpers";
import { buildEngine } from "discourse/static/markdown-it";

let engine;

function getEngine() {
  if (!engine) {
    // Typographer replacements (smart quotes, dashes, ellipsis, etc.) are a
    // rendering concern. We disable them in the rich editor so the document
    // mirrors the raw markdown source and round-trips without baking
    // typographic characters into the stored content.
    const { siteSettings } = helperContext();

    engine = buildEngine(
      { siteSettings: { ...siteSettings, enable_markdown_typographer: false } },
      ["onebox", "watched-words", "censored"]
    );
  }

  return engine;
}

export function resetEngine() {
  engine = null;
}

export const parse = (text) => getEngine().parse(text);

export const getLinkify = () => getEngine().linkify;

export const isWhiteSpace = (str, index) =>
  !str || getEngine().options.engine.utils.isWhiteSpace(str.charCodeAt(index));

export const isBoundary = (str, index) =>
  !str ||
  getEngine().options.engine.utils.isWhiteSpace(str.charCodeAt(index)) ||
  getEngine().options.engine.utils.isPunctChar(
    String.fromCharCode(str.charCodeAt(index))
  );
