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
        if (state.doc.rangeHasMark(start, end, state.schema.marks.code)) {
          return false;
        }

        return state.tr.replaceWith(
          start,
          end,
          state.schema.text(replaceRareStr(match[0]).trim())
        );
      },
    },
    {
      match: new RegExp(`(${SCOPED_ABBR_RE.source})$`, "i"),
      handler: (state, match, start, end) => {
        return state.tr.replaceWith(
          start,
          end,
          state.schema.text(replaceScopedStr(match[0]))
        );
      },
    },
  ],
};

export default extension;
