/** @type {RichEditorExtension} */
const extension = {
  // This is a 1-1 copy of the prosemirror-markdown bullet_list, but
  // overrides the tight list default to `true`
  nodeSpec: {
    bullet_list: {
      content: "list_item+",
      group: "block",
      attrs: { tight: { default: true } },
      parseDOM: [
        {
          tag: "ul",
          getAttrs: (dom) => ({ tight: dom.hasAttribute("data-tight") }),
        },
      ],
      toDOM: (node) => [
        "ul",
        { "data-tight": node.attrs.tight ? "true" : null },
        0,
      ],
    },
  },
};

export default extension;
