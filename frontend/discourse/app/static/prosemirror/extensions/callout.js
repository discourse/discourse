import { buildEmojiUrl, isCustomEmoji } from "pretty-text/emoji";
import { emojiOptions } from "discourse/lib/text";
import { i18n } from "discourse-i18n";
import {
  CALLOUT_EMOJIS,
  CALLOUT_MARKER,
  resolveCalloutEmoji,
} from "discourse-markdown-it/features/callouts";

function titleSpec({ type, emoji }) {
  const title = i18n(`post.callouts.${type}`);
  const attrs = { class: "callout__title", contenteditable: "false" };
  const opts = emojiOptions();
  const code = opts && resolveCalloutEmoji(type, emoji, opts);

  if (!code) {
    return ["p", attrs, title];
  }

  return [
    "p",
    attrs,
    [
      "img",
      {
        class: isCustomEmoji(code, opts) ? "emoji emoji-custom" : "emoji",
        alt: `:${code}:`,
        title: `:${code}:`,
        src: buildEmojiUrl(code, opts),
      },
    ],
    ` ${title}`,
  ];
}

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    callout: {
      attrs: { type: { default: "note" }, emoji: { default: null } },
      content: "block+",
      group: "block",
      defining: true,
      createGapCursor: true,
      parseDOM: [
        {
          tag: "div.callout",
          contentElement: "div.callout__content",
          getAttrs(dom) {
            const type = dom.dataset.calloutType;

            if (!Object.hasOwn(CALLOUT_EMOJIS, type)) {
              return false;
            }

            return { type, emoji: dom.dataset.calloutEmoji ?? null };
          },
        },
      ],
      toDOM(node) {
        return [
          "div",
          {
            class: "callout",
            "data-callout-type": node.attrs.type,
            "data-callout-emoji": node.attrs.emoji,
          },
          titleSpec(node.attrs),
          ["div", { class: "callout__content" }, 0],
        ];
      },
    },
  },

  parse: {
    callout: {
      block: "callout",
      getAttrs: (token) => ({
        type: token.attrGet("data-callout-type"),
        emoji: token.attrGet("data-callout-emoji"),
      }),
    },
  },

  serializeNode: {
    callout(state, node) {
      const { type, emoji } = node.attrs;
      const options = emoji ? ` emoji=${emoji}` : "";

      state.wrapBlock("> ", null, node, () => {
        state.write(`[!${type.toUpperCase()}${options}]`);
        state.ensureNewLine();
        state.renderContent(node);
      });
    },
  },

  inputRules: ({ pmTransform: { findWrapping } }) => ({
    match: CALLOUT_MARKER,
    handler(state, match, start, end) {
      const { blockquote, callout } = state.schema.nodes;
      const attrs = {
        type: match[1].toLowerCase(),
        emoji: match[2]?.toLowerCase() ?? null,
      };

      const tr = state.tr.delete(start, end);
      const $start = tr.doc.resolve(start);

      // a marker typed at the start of a quote converts it, as in markdown
      if ($start.node(-1).type === blockquote && $start.index(-1) === 0) {
        return tr.setNodeMarkup($start.before(-1), callout, attrs);
      }

      const range = $start.blockRange();
      const wrapping = range && findWrapping(range, callout, attrs);

      return wrapping ? tr.wrap(range, wrapping) : null;
    },
  }),

  plugins: ({ pmState: { Plugin, NodeSelection } }) =>
    new Plugin({
      props: {
        handleClickOn(view, pos, node, nodePos, event) {
          const title = event.target.closest(".callout__title");

          if (
            node.type.name !== "callout" ||
            !title ||
            title.parentElement !== view.nodeDOM(nodePos)
          ) {
            return false;
          }

          view.dispatch(
            view.state.tr.setSelection(
              NodeSelection.create(view.state.doc, nodePos)
            )
          );

          return true;
        },
      },
    }),
};

export default extension;
