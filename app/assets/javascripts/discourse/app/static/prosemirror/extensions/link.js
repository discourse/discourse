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
  plugins: ({ pmState: { Plugin }, utils }) =>
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
