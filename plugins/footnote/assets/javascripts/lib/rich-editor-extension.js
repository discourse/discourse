export default {
  nodeSpec: {
    footnote: {
      attrs: { id: {} },
      group: "group",
      content: "group*",
      atom: true,
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "span.footnote",
          preserveWhitespace: "full",
          getAttrs: (dom) => {
            return { id: dom.getAttribute("data-id") };
          },
        },
      ],
      toDOM: (node) => {
        return ["span", { class: "footnote", "data-id": node.attrs.id }, [0]];
      },
    },
  },
  parse: {
    footnote_block: { ignore: true },
    footnote: {
      ignore: true,
      // block: "footnote",
      // getAttrs: (token, tokens, i) => ({ id: token.meta.id }),
    },
    footnote_anchor: { ignore: true, noCloseToken: true },
    footnote_ref: {
      node: "footnote",
      getAttrs: (token, tokens, i) => ({ id: token.meta.id }),
    },
  },
  serializeNode: {
    footnote: (state, node) => {
      state.write(`^[${node.attrs.id}] `);
    },
  },
};
