// @ts-check

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

// Patterns from prosemirror-inputrules smart quote rules
const SMART_QUOTE_PATTERNS = [
  /(?:^|[\s{[(<'"\u2018\u201C])(")$/, // open double
  /"$/, // close double
  /(?:^|[\s{[(<'"\u2018\u201C])(')$/, // open single
  /'$/, // close single
];

function buildSmartQuoteRules(quotationMarks) {
  const quotes = quotationMarks.split("|");

  return SMART_QUOTE_PATTERNS.map((match, i) => ({
    match,
    handler: quotes[i],
  }));
}

export function buildTypographyReverseMap(siteSettings) {
  if (!siteSettings?.enable_markdown_typographer) {
    return {};
  }

  const quotes = siteSettings.markdown_typographer_quotation_marks.split("|");
  const map = { ...BASE_TEXT_REPLACEMENTS };

  map[quotes[0]] = '"';
  map[quotes[1]] = '"';
  map[quotes[2]] = "'";
  map[quotes[3]] = "'";

  return map;
}

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  inputRules: ({ getContext }) => {
    const siteSettings = getContext().siteSettings;
    const rules = [];

    if (siteSettings.enable_markdown_typographer) {
      rules.push(
        {
          match: new RegExp(`(${RARE_RE.source})$`),
          handler: (state, match, start, end) => {
            return state.tr.replaceWith(
              start,
              end,
              state.schema.text(replaceRareStr(match[0]).trim())
            );
          },
        },
        {
          // existing for markdown-it, plus: en-dash + hyphen -> em-dash
          match: new RegExp(`(${SCOPED_ABBR_RE.source}|\u2013-)$`, "i"),
          handler: (state, match, start, end) => {
            return state.tr.replaceWith(
              start,
              end,
              state.schema.text(
                replaceScopedStr(match[0]).replace(/\u2013-$/, "\u2014")
              )
            );
          },
        }
      );

      rules.push(
        ...buildSmartQuoteRules(
          siteSettings.markdown_typographer_quotation_marks
        )
      );
    }

    return rules;
  },
};

export default extension;
