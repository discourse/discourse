import { helperContext } from "discourse/lib/helpers";
import { buildEngine } from "discourse/static/markdown-it";

const engines = new Map();

/**
 * The engine cooking with the host's `featuresOverride` and `markdownItRules`,
 * so parsing follows the host's own rendering. Hosts without them share the
 * full engine.
 */
function getEngine(markdownOptions) {
  const { featuresOverride, markdownItRules } = markdownOptions ?? {};
  const key = JSON.stringify([featuresOverride, markdownItRules]);

  if (!engines.has(key)) {
    // Typographer replacements (smart quotes, dashes, ellipsis, etc.) are a
    // rendering concern. We disable them in the rich editor so the document
    // mirrors the raw markdown source and round-trips without baking
    // typographic characters into the stored content.
    const { siteSettings } = helperContext();

    engines.set(
      key,
      buildEngine(
        {
          siteSettings: { ...siteSettings, enable_markdown_typographer: false },
          featuresOverride,
          markdownItRules,
        },
        ["onebox", "watched-words", "censored"]
      )
    );
  }

  return engines.get(key);
}

export function resetEngine() {
  engines.clear();
}

export const parse = (text, markdownOptions) =>
  getEngine(markdownOptions).parse(text);

/** @returns {import("discourse/lib/link-matcher").LinkMatcher} */
export const getLinkify = () => getEngine().linkify;

export const getAllowLister = () => getEngine().allowLister;

export const isWhiteSpace = (str, index) =>
  !str || getEngine().options.engine.utils.isWhiteSpace(str.charCodeAt(index));

export const isBoundary = (str, index) =>
  !str ||
  getEngine().options.engine.utils.isWhiteSpace(str.charCodeAt(index)) ||
  getEngine().options.engine.utils.isPunctChar(
    String.fromCharCode(str.charCodeAt(index))
  );
