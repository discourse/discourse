/** @type {RichEditorExtension} */
const extension = {
  markSpec: {
    underline: {
      toDOM() {
        return ["u", 0];
      },
      parseDOM: [{ tag: "u" }],
    },
  },
  inputRules: ({ schema, markInputRule }) =>
    markInputRule(/\[u]$/, schema.marks.underline),
  keymap({ pmCommands, schema }) {
    return { "Mod-u": pmCommands.toggleMark(schema.marks.underline) };
  },
  parse: {
    bbcode_u: { mark: "underline" },
  },
  serializeMark: {
    underline: {
      open: "[u]",
      close: "[/u]",
      mixable: true,
      expelEnclosingWhitespace: true,
    },
  },
};

export default extension;
