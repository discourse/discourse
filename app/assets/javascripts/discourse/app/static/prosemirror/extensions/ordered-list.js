/** @type {RichEditorExtension} */
const extension = {
  // This is a 1-1 copy of the prosemirror-markdown ordered_list, but
  // overrides the tight list default to `true`
  nodeSpec: {
    ordered_list: {
      content: "list_item+",
      group: "block",
      attrs: { order: { default: 1 }, tight: { default: true } },
      parseDOM: [
        {
          tag: "ol",
          getAttrs: (dom) => ({ tight: dom.hasAttribute("data-tight") }),
        },
      ],
      toDOM: (node) => {
        return [
          "ol",
          {
            start: node.attrs.order === 1 ? null : node.attrs.order,
            "data-tight": node.attrs.tight ? "true" : null,
          },
          0,
        ];
      },
    },
  },
};

export default extension;
