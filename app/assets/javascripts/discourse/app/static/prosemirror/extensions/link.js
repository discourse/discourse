import { ReplaceAroundStep, ReplaceStep } from "prosemirror-transform";
import { getChangedRanges } from "discourse/static/prosemirror/lib/plugin-utils";

const AUTO_LINKS = ["autolink", "linkify"];
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
        attachment: { default: null },
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
            "data-orig-href": node.attrs["data-orig-href"],
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
        const attachment = tokens[i + 1].content.endsWith("|attachment");
        if (attachment) {
          tokens[i + 1].content = tokens[i + 1].content.replace(
            /\|attachment$/,
            ""
          );
        }

        return {
          href: tok.attrGet("href"),
          title: tok.attrGet("title") || null,
          markup: tok.markup,
          attachment,
          "data-orig-href": tok.attrGet("data-orig-href"),
        };
      },
    },
  },
  serializeMark: {
    // override mark serializer to support "|attachment"
    link: {
      open(state, mark, parent, index) {
        state.linkMarkup =
          mark.attrs.markup ??
          (isPlainURL(mark, parent, index) ? "autolink" : null);

        if (state.linkMarkup === "autolink") {
          return "<";
        }

        if (state.linkMarkup === "linkify") {
          return "";
        }

        return "[";
      },
      close(state, mark) {
        let { linkMarkup } = state;
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
  inputRules: ({ schema, utils }) =>
    utils.markInputRule(
      /\[([^\]]+)]\(([^)\s]+)(?:\s+[“"']([^“"']+)[”"'])?\)$/,
      schema.marks.link,
      (match) => {
        return { href: match[2], title: match[3] };
      }
    ),
  plugins: ({ pmState: { Plugin }, utils }) => [
    new Plugin({
      props: {
        // Auto-linkify plain-text pasted URLs
        clipboardTextParser(text, $context, plain, view) {
          if (view.state.selection.empty || !utils.getLinkify().test(text)) {
            return;
          }

          return addLinkMark(view, text);
        },

        // Auto-linkify rich content with a single text node that is a URL
        transformPasted(paste, view) {
          let node = null;

          if (paste.content.childCount === 1) {
            if (paste.content.firstChild.isText) {
              node = paste.content.firstChild;
            } else if (
              paste.content.firstChild.type.name === "paragraph" &&
              paste.content.firstChild.childCount === 1 &&
              paste.content.firstChild.firstChild.isText
            ) {
              node = paste.content.firstChild.firstChild;
            }
          }

          if (
            !node?.text ||
            node?.marks.some((mark) => mark.type.name === "link")
          ) {
            return paste;
          }

          const matches = utils.getLinkify().match(node.text);
          const isFullMatch =
            matches && matches.length === 1 && matches[0].raw === node.text;

          if (!isFullMatch) {
            return paste;
          }

          return addLinkMark(view, node.text);
        },
      },
    }),
    // plugin for auto-linking during typing
    new Plugin({
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
          state.doc.nodesBetween(from, to, (node, pos) => {
            if (
              !node.isText ||
              node.marks.some(
                (mark) =>
                  (mark.type.name === "link" &&
                    !AUTO_LINKS.includes(mark.attrs.markup)) ||
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
              nodeBefore.marks.length === 1 &&
              nodeBefore.marks.some(
                (mark) =>
                  mark.type.name === "link" &&
                  AUTO_LINKS.includes(mark.attrs.markup)
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
                  mark.type.name === "link" &&
                  AUTO_LINKS.includes(mark.attrs.markup)
              )
            ) {
              textAfter = nodeAfter.text;
            }

            const fullText = textBefore + textSlice + textAfter;

            const startPos = pos + wordStart - textBefore.length;

            tr.removeMark(
              startPos,
              startPos + fullText.length,
              state.schema.marks.link
            );

            utils
              .getLinkify()
              .match(fullText)
              ?.forEach((match) => {
                // small exception when we're typing `www.link.com
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
  ],
};

function addLinkMark(view, href) {
  const { from, to } = view.state.selection;
  const linkMark = view.state.schema.marks.link.create({ href });

  const tr = view.state.tr;
  tr.addMark(from, to, linkMark);

  return tr.doc.slice(from, to);
}

function isPlainURL(link, parent, index) {
  if (link.attrs.title || !/^\w+:/.test(link.attrs.href)) {
    return false;
  }
  let content = parent.child(index);
  if (
    !content.isText ||
    content.text !== link.attrs.href ||
    content.marks[content.marks.length - 1] !== link
  ) {
    return false;
  }
  return (
    index === parent.childCount - 1 ||
    !link.isInSet(parent.child(index + 1).marks)
  );
}

export default extension;
