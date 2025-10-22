import {
  RARE_RE,
  replaceRareStr,
  replaceScopedStr,
  SCOPED_ABBR_RE,
} from "discourse-markdown-it/features/custom-typographer-replacements";

// TODO(renato): should respect `enable_markdown_typographer`

/** @type {RichEditorExtension} */
const extension = {
  inputRules: [
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
    },
  ],
};

export default extension;
