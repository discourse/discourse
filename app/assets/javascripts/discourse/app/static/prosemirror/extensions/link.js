import { ReplaceAroundStep, ReplaceStep } from "prosemirror-transform";
import {
  getChangedRanges,
  markInputRule,
} from "discourse/static/prosemirror/lib/plugin-utils";

const REPLACE_STEPS = [ReplaceStep, ReplaceAroundStep];

/** @type {RichEditorExtension} */
const extension = {
  markSpec: {
    link: {
      attrs: {
        href: {},
        title: { default: null },
        // same value from the markdown-it token
        // null for [link](...), "autolink" for <...>, and "linkify" for plain URLs
        markup: { default: null },
        attachment: { default: false },
        "data-orig-href": { default: null },
      },
      inclusive: false,
      parseDOM: [
        {
          tag: "a[href]",
          getAttrs(dom) {
            return {
              href: dom.getAttribute("href"),
              title: dom.getAttribute("title"),
              attachment: dom.classList.contains("attachment"),
              "data-orig-href": dom.getAttribute("data-orig-href"),
              markup: dom.getAttribute("data-markup"),
            };
          },
        },
      ],
      toDOM(node) {
        return [
          "a",
          {
            href: node.attrs.href,
            title: node.attrs.title,
            class: node.attrs.attachment ? "attachment" : undefined,
            "data-orig-href": node.attrs["data-orig-href"] || undefined,
            "data-markup": node.attrs.markup || undefined,
          },
          0,
        ];
      },
    },
  },
  parse: {
    link: {
      mark: "link",
      getAttrs(tok, tokens, i) {
        const nextContent = tokens[i + 1].content;
        const attachment = nextContent.endsWith("|attachment");
        if (attachment) {
          tokens[i + 1].content = nextContent.slice(0, -11);
        }

        return {
          href: tok.attrGet("href"),
          title: tok.attrGet("title") || null,
          markup: tok.markup || null,
          attachment,
          "data-orig-href": tok.attrGet("data-orig-href"),
        };
      },
    },
  },
  serializeMark: {
    // override mark serializer to support "|attachment"
    link: {
      open(state, mark) {
        state.linkMarkup = mark.attrs.markup;

        if (state.linkMarkup === "autolink") {
          return "<";
        }

        if (state.linkMarkup === "linkify") {
          return "";
        }

        return "[";
      },
      close(state, mark) {
        const { linkMarkup } = state;
        state.linkMarkup = undefined;

        if (linkMarkup === "autolink") {
          return ">";
        }

        if (linkMarkup === "linkify") {
          return "";
        }

        const attachment = mark.attrs.attachment ? "|attachment" : "";
        const href =
          mark.attrs["data-orig-href"] ??
          mark.attrs.href.replace(/[()"]/g, "\\$&");
        const title = mark.attrs.title
          ? ` "${mark.attrs.title.replace(/"/g, '\\"')}"`
          : "";

        return `${attachment}](${href}${title})`;
      },
      mixable: true,
    },
  },
  inputRules: ({ schema }) => [
    markInputRule(
      /\[([^\]]+)]\(([^)\s]+)(?:\s+[“"']([^“"']+)[”"'])?\)$/,
      schema.marks.link,
      (match) => {
        return { href: match[2], title: match[3] };
      }
    ),
    markInputRule(
      // AUTOLINK_RE from https://github.com/markdown-it/markdown-it/blob/master/lib/rules_inline/autolink.mjs
      /<([a-zA-Z][a-zA-Z0-9+.-]{1,31}:[^<>\x00-\x20]*)>$/,
      schema.marks.link,
      (match) => {
        return { href: match[1], markup: "autolink" };
      }
    ),
  ],
  plugins: ({ pmState: { Plugin }, utils }) =>
    new Plugin({
      props: {
        // Auto-linkify plain-text pasted URLs over a selection
        clipboardTextParser(text, $context, plain, view) {
          if (view.state.selection.empty || !utils.getLinkify().test(text)) {
            return;
          }

          return addLinkMark(view, text, utils);
        },
        // Auto-linkify pasted rich content with a single text node that is a URL over a selection
        transformPasted(slice, view) {
          if (view.state.selection.empty) {
            return slice;
          }

          let node = null;

          if (slice.content.childCount === 1) {
            if (slice.content.firstChild.isText) {
              node = slice.content.firstChild;
            } else if (
              slice.content.firstChild.type.name === "paragraph" &&
              slice.content.firstChild.childCount === 1 &&
              slice.content.firstChild.firstChild.isText
            ) {
              node = slice.content.firstChild.firstChild;
            }
          }

          if (
            !node?.text ||
            node?.marks.some(
              (mark) => mark.type.name === "link" || mark.type.name === "code"
            ) ||
            !utils.getLinkify().test(node.text)
          ) {
            return slice;
          }

          return addLinkMark(view, node.text, utils);
        },
      },

      // Automatically adds and removes link marks when typing
      appendTransaction(transactions, prevState, state) {
        const transaction = prevState.tr;
        transactions
          .filter((tr) => tr.docChanged && tr.getMeta("addToHistory") !== false)
          .flatMap((tr) => tr.steps)
          .forEach((step) => {
            if (REPLACE_STEPS.includes(step.constructor)) {
              transaction.step(step);
            }
          });

        const changedRanges = getChangedRanges(transaction);

        const tr = state.tr;

        changedRanges.forEach((change) => {
          let from = change.new.from;
          let to = change.new.to;
          if (from === to) {
            from = Math.max(from - 1, 0);
            to = Math.min(to + 1, state.doc.nodeSize - 2);
          }

          // stores the nodes visited ahead, skipping a node if already seen in nodeAfter
          const visited = new Set();
          state.doc.nodesBetween(from, to, (node, pos) => {
            if (
              visited.has(node) ||
              !node.isText ||
              node.marks.some(
                (mark) =>
                  (mark.type.name === "link" &&
                    mark.attrs.markup !== "linkify") ||
                  mark.type.name === "code"
              )
            ) {
              return true;
            }

            const text = node.text;

            const changeStart = Math.max(0, change.new.from - pos);
            const changeEnd = Math.min(text.length, change.new.to - pos);

            let wordStart = changeStart;
            while (wordStart > 0 && !utils.isWhiteSpace(text[wordStart - 1])) {
              wordStart--;
            }
            let wordEnd = changeEnd;
            while (
              wordEnd < text.length &&
              !utils.isWhiteSpace(text[wordEnd])
            ) {
              wordEnd++;
            }

            const textSlice = text.slice(wordStart, wordEnd);

            const nodeBefore = state.doc.nodeAt(pos - 1);
            let textBefore = "";

            if (
              wordStart === 0 &&
              nodeBefore?.isText &&
              !utils.isWhiteSpace(
                nodeBefore.text[nodeBefore.text.length - 1]
              ) &&
              !utils.isWhiteSpace(text[0]) &&
              !nodeBefore.marks.some(
                (mark) =>
                  mark.type.name === "link" && mark.attrs.markup !== "linkify"
              )
            ) {
              textBefore = nodeBefore.text;
            }

            const nodeAfter = state.doc.nodeAt(pos + node.nodeSize);
            let textAfter = "";
            if (
              wordEnd === text.length &&
              nodeAfter?.isText &&
              !utils.isWhiteSpace(text[text.length - 1]) &&
              !utils.isWhiteSpace(nodeAfter.text[0]) &&
              nodeAfter.marks.length === 1 &&
              nodeAfter.marks.some(
                (mark) =>
                  mark.type.name === "link" && mark.attrs.markup === "linkify"
              )
            ) {
              textAfter = nodeAfter.text;
              visited.add(nodeAfter);
            }

            const fullText = textBefore + textSlice + textAfter;

            const startPos = pos + wordStart - textBefore.length;

            tr.removeMark(
              startPos,
              startPos + fullText.length,
              state.schema.marks.link
            );

            if (!utils.getLinkify().test(fullText)) {
              return;
            }

            utils
              .getLinkify()
              .match(fullText)
              ?.forEach((match) => {
                // ignore if the match is just after a `
                if (fullText[match.index - 1] === "`") {
                  return;
                }

                tr.addMark(
                  startPos + match.index,
                  startPos + match.index + match.raw.length,
                  state.schema.marks.link.create({
                    href: match.url,
                    markup: "linkify",
                  })
                );
              });
          });
        });

        return tr;
      },
    }),
};

function addLinkMark(view, text, utils) {
  const matches = utils.getLinkify().match(text);
  const isFullMatch = matches?.length === 1 && matches[0].raw === text;

  if (!isFullMatch) {
    return;
  }

  const { from, to } = view.state.selection;
  const tr = view.state.tr;

  // used only when replacing the selection, so no markup: linkify
  tr.addMark(from, to, view.state.schema.marks.link.create({ href: text }));

  return tr.doc.slice(from, to);
}

export default extension;
