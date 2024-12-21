import { mentionRegex } from "pretty-text/mentions";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

export default {
  nodeSpec: {
    mention: {
      attrs: { name: {} },
      inline: true,
      group: "inline",
      content: "text*",
      atom: true,
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "a.mention",
          preserveWhitespace: "full",
          getAttrs: (dom) => {
            return { name: dom.getAttribute("data-name") };
          },
        },
      ],
      toDOM: (node) => {
        return [
          "a",
          { class: "mention", "data-name": node.attrs.name },
          `@${node.attrs.name}`,
        ];
      },
      leafText: (node) => `@${node.attrs.name}`,
    },
  },

  inputRules: [
    {
      // TODO(renato): pass unicodeUsernames?
      match: new RegExp(`(?<=^|\\W)(${mentionRegex().source}) $`),
      handler: (state, match, start, end) =>
        state.selection.$from.nodeBefore?.type !== state.schema.nodes.mention &&
        state.tr.replaceWith(start, end, [
          state.schema.nodes.mention.create({ name: match[1].slice(1) }),
          state.schema.text(" "),
        ]),
      options: { undoable: false },
    },
  ],

  parse: {
    mention: {
      block: "mention",
      getAttrs: (token, tokens, i) => ({
        // this is not ideal, but working around the mention_open/close structure
        // a text is expected just after the mention_open token
        name: tokens[i + 1].content.slice(1),
      }),
    },
  },

  serializeNode: {
    mention: (state, node, parent, index) => {
      if (!isBoundary(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.write(`@${node.attrs.name}`);

      const nextSibling =
        parent.childCount > index + 1 ? parent.child(index + 1) : null;
      if (nextSibling?.isText && !isBoundary(nextSibling.text, 0)) {
        state.write(" ");
      }
    },
  },
};
