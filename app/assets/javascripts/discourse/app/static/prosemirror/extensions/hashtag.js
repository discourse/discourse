import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    hashtag: {
      attrs: { name: {} },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "a.hashtag-cooked",
          preserveWhitespace: "full",
          getAttrs: (dom) => {
            return { name: dom.getAttribute("data-name") };
          },
        },
      ],
      toDOM: (node) => {
        return [
          "a",
          { class: "hashtag-cooked", "data-name": node.attrs.name },
          `#${node.attrs.name}`,
        ];
      },
    },
  },

  inputRules: [
    {
      match: /(^|\W)(#[\u00C0-\u1FFF\u2C00-\uD7FF\w:-]{1,101})\s$/,
      handler: (state, match, start, end) => {
        const hashtagStart = start + match[1].length;
        const name = match[2].slice(1);
        return (
          state.selection.$from.nodeBefore?.type !==
            state.schema.nodes.hashtag &&
          state.tr.replaceWith(hashtagStart, end, [
            state.schema.nodes.hashtag.create({ name }),
            state.schema.text(" "),
          ])
        );
      },
      options: { undoable: false },
    },
  ],

  parse: {
    span_open(state, token, tokens, i) {
      if (token.attrGet("class") === "hashtag-raw") {
        state.openNode(state.schema.nodes.hashtag, {
          // this is not ideal, but working around the span_open/close structure
          // a text is expected just after the span_open token
          name: tokens.splice(i + 1, 1)[0].content.slice(1),
        });
        return true;
      }
    },
    span_close(state) {
      if (state.top().type.name === "hashtag") {
        state.closeNode();
        return true;
      }
    },
  },

  serializeNode: {
    hashtag(state, node, parent, index) {
      state.flushClose();
      if (!isBoundary(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.write(`#${node.attrs.name}`);

      const nextSibling =
        parent.childCount > index + 1 ? parent.child(index + 1) : null;
      if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
        state.write(" ");
      }
    },
  },
};

export default extension;
