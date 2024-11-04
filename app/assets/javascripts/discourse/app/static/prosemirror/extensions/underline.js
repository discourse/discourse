export default {
  markSpec: {
    underline: {
      toDOM() {
        return ["u", 0];
      },
      parseDOM: [{ tag: "u" }],
    },
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
