import { buildEmojiUrl, emojiExists, isCustomEmoji } from "pretty-text/emoji";
import { emojiOptions } from "discourse/lib/text";

// TODO(renato): we need to avoid the invalid text:emoji: state (reminder to use isPunctChar to avoid deleting the space)
export default {
  nodeSpec: {
    emoji: {
      attrs: { code: {} },
      inline: true,
      group: "inline",
      draggable: true,
      selectable: false,
      parseDOM: [
        {
          tag: "img.emoji",
          getAttrs: (dom) => {
            return { code: dom.getAttribute("alt").replace(/:/g, "") };
          },
        },
      ],
      toDOM: (node) => {
        const opts = emojiOptions();
        const code = node.attrs.code.toLowerCase();
        const title = `:${code}:`;
        const src = buildEmojiUrl(code, opts);

        return [
          "img",
          {
            class: isCustomEmoji(code, opts) ? "emoji emoji-custom" : "emoji",
            alt: title,
            title,
            src,
          },
        ];
      },
      leafText: (node) => `:${node.attrs.code}:`,
    },
  },

  inputRules: [
    {
      match: /(?<=^|\W):([^:]+):$/,
      handler: (state, match, start, end) => {
        if (emojiExists(match[1])) {
          return state.tr.replaceWith(
            start,
            end,
            state.schema.nodes.emoji.create({ code: match[1] })
          );
        }
      },
      options: { undoable: false },
    },
  ],

  parse: {
    emoji: {
      node: "emoji",
      getAttrs: (token) => ({
        code: token.attrGet("alt").slice(1, -1),
      }),
    },
  },

  serializeNode: {
    emoji: (state, node) => {
      state.write(`:${node.attrs.code}:`);
    },
  },
};
