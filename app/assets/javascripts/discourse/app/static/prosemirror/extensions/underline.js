export default {
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
