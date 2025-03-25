/** @type {RichEditorExtension} */
const extension = {
  markSpec: {
    strikethrough: {
      before: "link",
      parseDOM: [
        { tag: "s" },
        { tag: "del" },
        {
          getAttrs: (value) =>
            /(^|[\s])line-through([\s]|$)/u.test(value) && null,
          style: "text-decoration",
        },
      ],
      toDOM() {
        return ["s"];
      },
    },
  },
  inputRules: ({ schema, utils }) =>
    utils.markInputRule(/~~([^~]+)~~$/, schema.marks.strikethrough),
  parse: {
    s: { mark: "strikethrough" },
    bbcode_s: { mark: "strikethrough" },
  },
  serializeMark: {
    strikethrough: {
      open: "~~",
      close: "~~",
      mixable: true,
      expelEnclosingWhitespace: true,
    },
  },
};

export default extension;
