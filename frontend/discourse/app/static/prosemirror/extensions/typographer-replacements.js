// @ts-check

import { InputRule } from "prosemirror-inputrules";
import {
  RARE_RE,
  replaceRareStr,
  replaceScopedStr,
  SCOPED_ABBR_RE,
} from "discourse-markdown-it/features/custom-typographer-replacements";

const BASE_TEXT_REPLACEMENTS = {
  "\u2014": "---", // em-dash
  "\u2013": "--", // en-dash
  "\u2026": "...", // ellipsis
  "\u00b1": "+-", // plus-minus
  "\u2192": "->", // right arrow
  "\u2190": "<-", // left arrow
  "\u2194": "<->", // left-right arrow
  "\u2122": "(tm)", // trademark
  "\u00b6": "(pa)", // pilcrow
};

// Smart quote patterns from prosemirror-inputrules
const SMART_QUOTE_PATTERNS = [
  /(?:^|[\s{[(<'"\u2018\u201C])(")$/, // open double
  /"$/, // close double
  /(?:^|[\s{[(<'"\u2018\u201C])(')$/, // open single
  /'$/, // close single
];

export function buildTypographyReverseMap(siteSettings) {
  if (!siteSettings?.enable_markdown_typographer) {
    return {};
  }

  const map = { ...BASE_TEXT_REPLACEMENTS };
  const quotes =
    /** @type {string} */
    (siteSettings.markdown_typographer_quotation_marks)?.split("|");

  if (quotes?.length === 4) {
    map[quotes[0]] = '"';
    map[quotes[1]] = '"';
    map[quotes[2]] = "'";
    map[quotes[3]] = "'";
  }

  return map;
}

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  inputRules: ({ getContext }) => {
    const siteSettings = getContext()?.siteSettings;
    if (!siteSettings?.enable_markdown_typographer) {
      return [];
    }

    const rules = [
      new InputRule(
        new RegExp(`(${RARE_RE.source})$`),
        (state, match, start, end) => {
          return state.tr.replaceWith(
            start,
            end,
            state.schema.text(replaceRareStr(match[0]).trim())
          );
        }
      ),
      // existing for markdown-it, plus: en-dash + hyphen -> em-dash
      new InputRule(
        new RegExp(`(${SCOPED_ABBR_RE.source}|\u2013-)$`, "i"),
        (state, match, start, end) => {
          return state.tr.replaceWith(
            start,
            end,
            state.schema.text(
              replaceScopedStr(match[0]).replace(/\u2013-$/, "\u2014")
            )
          );
        }
      ),
    ];

    const quotes =
      /** @type {string} */
      (siteSettings.markdown_typographer_quotation_marks)?.split("|");

    if (quotes?.length !== 4) {
      return rules;
    }

    return [
      ...rules,
      ...SMART_QUOTE_PATTERNS.map(
        (pattern, i) => new InputRule(pattern, quotes[i], { inCodeMark: false })
      ),
    ];
  },
};

export default extension;
