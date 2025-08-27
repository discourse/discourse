import { buildEmojiUrl, emojiExists, isCustomEmoji } from "pretty-text/emoji";
import { translations } from "pretty-text/emoji/data";
import { Plugin } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";
import escapeRegExp from "discourse/lib/escape-regexp";
import { emojiOptions } from "discourse/lib/text";
import { isBoundary } from "discourse/static/prosemirror/lib/markdown-it";
import { getChangedRanges } from "discourse/static/prosemirror/lib/plugin-utils";

/**
 * Plugin that adds the only-emoji class to emojis
 * @returns {Plugin} ProseMirror plugin
 */
function createOnlyEmojiPlugin() {
  return new Plugin({
    state: {
      init() {
        return DecorationSet.empty;
      },
      apply(tr, oldSet, oldState, newState) {
        if (!tr.docChanged) {
          return oldSet.map(tr.mapping, tr.doc);
        }

        const changedRanges = getChangedRanges(tr);
        let newSet = oldSet.map(tr.mapping, tr.doc);

        changedRanges.forEach(({ new: { from, to } }) => {
          // traverse all text blocks in the changed range
          newState.doc.nodesBetween(from, to, (node, pos) => {
            if (!node.isTextblock) {
              return true;
            }

            const blockFrom = pos;
            const blockTo = pos + node.nodeSize;

            const existingDecorations = newSet.find(blockFrom, blockTo);
            newSet = newSet.remove(existingDecorations);

            const emojiNodes = [];
            let hasOnlyEmojis = true;

            // collect emojis in the current text block
            node.descendants((child, childPos) => {
              if (child.type.name === "emoji") {
                emojiNodes.push({
                  from: blockFrom + 1 + childPos,
                  to: blockFrom + 1 + childPos + child.nodeSize,
                });

                return true;
              }

              if (child.type.name === "text" && !child.text?.trim()) {
                return true;
              }

              hasOnlyEmojis = false;
              return false;
            });

            if (
              emojiNodes.length > 0 &&
              emojiNodes.length <= 3 &&
              hasOnlyEmojis
            ) {
              const decorations = emojiNodes.map((emoji) =>
                Decoration.inline(emoji.from, emoji.to, {
                  class: "only-emoji",
                })
              );
              newSet = newSet.add(newState.doc, decorations);
            }

            return false;
          });
        });

        return newSet;
      },
    },
    props: {
      decorations(state) {
        return this.getState(state);
      },
    },
  });
}

/** @type {RichEditorExtension} */
const extension = {
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
          priority: 60,
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
    },
  },

  inputRules: [
    {
      match: /(^|\W):([^:]+):$/,
      handler: (state, match, start, end) => {
        if (emojiExists(match[2])) {
          const emojiStart = start + match[1].length;
          const emojiNode = state.schema.nodes.emoji.create({ code: match[2] });
          const tr = state.tr.replaceWith(emojiStart, end, emojiNode);

          state.doc
            .resolve(emojiStart)
            .marks()
            .forEach((mark) => {
              tr.addMark(emojiStart, emojiStart + 1, mark);
            });
          return tr;
        }
      },
      options: { undoable: false },
    },
    {
      match: new RegExp(
        "(^|\\W)(" +
          Object.keys(translations).map(escapeRegExp).join("|") +
          ") $"
      ),
      handler: (state, match, start, end) => {
        const emojiStart = start + match[1].length;
        const emojiNode = state.schema.nodes.emoji.create({
          code: translations[match[2]],
        });
        const tr = state.tr
          .replaceWith(emojiStart, end, emojiNode)
          .insertText(" ");

        state.doc
          .resolve(emojiStart)
          .marks()
          .forEach((mark) => {
            tr.addMark(emojiStart, emojiStart + 2, mark);
          });
        return tr;
      },
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
    emoji(state, node) {
      state.flushClose();
      if (!isBoundary(state.out, state.out.length - 1)) {
        state.write(" ");
      }

      state.write(`:${node.attrs.code}:`);
    },
  },

  plugins: () => [createOnlyEmojiPlugin()],
};

export default extension;
