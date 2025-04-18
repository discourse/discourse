import { mentionRegex } from "pretty-text/mentions";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    mention: {
      attrs: { name: {} },
      inline: true,
      group: "inline",
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
    },
  },

  inputRules: {
    // TODO(renato): pass unicodeUsernames?
    match: new RegExp(`(^|\\W)(${mentionRegex().source}) $`),
    handler: (state, match, start, end) => {
      const { $from } = state.selection;
      if ($from.nodeBefore?.type === state.schema.nodes.mention) {
        return null;
      }
      const mentionStart = start + match[1].length;
      const name = match[2].slice(1);
      return state.tr.replaceWith(mentionStart, end, [
        state.schema.nodes.mention.create({ name }),
        state.schema.text(" "),
      ]);
    },
    options: { undoable: false },
  },

  parse: {
    mention: {
      block: "mention",
      getAttrs: (token, tokens, i) => ({
        // this is not ideal, but working around the mention_open/close structure
        // a text is expected just after the mention_open token
        name: tokens.splice(i + 1, 1)[0].content.slice(1),
      }),
    },
  },

  serializeNode: {
    mention(state, node, parent, index) {
      state.flushClose();
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

export default extension;
