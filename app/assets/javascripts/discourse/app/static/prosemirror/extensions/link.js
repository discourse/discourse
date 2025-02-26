/** @type {RichEditorExtension} */
const extension = {
  markSpec: {
    link: {
      attrs: {
        href: {},
        title: { default: null },
        autoLink: { default: null },
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
          autoLink: tok.markup === "autolink",
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
        state.inAutolink = isPlainURL(mark, parent, index);
        return state.inAutolink ? "<" : "[";
      },
      close(state, mark) {
        let { inAutolink } = state;
        state.inAutolink = undefined;

        if (inAutolink) {
          return ">";
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
  inputRules: ({ schema, markInputRule }) =>
    markInputRule(
      /\[([^\]]+)]\(([^)\s]+)(?:\s+[“"']([^“"']+)[”"'])?\)$/,
      schema.marks.link,
      (match) => {
        return { href: match[2], title: match[3] };
      }
    ),
  plugins: ({ pmState: { Plugin }, pmModel: { Slice, Fragment }, utils }) =>
    new Plugin({
      props: {
        // Auto-linkify plain-text pasted URLs
        clipboardTextParser(text, $context, plain, view) {
          if (view.state.selection.empty || !utils.getLinkify().test(text)) {
            return;
          }

          const marks = $context.marks();
          const selectedText = view.state.doc.textBetween(
            view.state.selection.from,
            view.state.selection.to
          );
          const textNode = view.state.schema.text(selectedText, [
            ...marks,
            view.state.schema.marks.link.create({ href: text }),
          ]);
          return new Slice(Fragment.from(textNode), 0, 0);
        },

        // Auto-linkify rich content with a single text node that is a URL
        transformPasted(paste, view) {
          if (
            paste.content.childCount === 1 &&
            paste.content.firstChild.isText &&
            !paste.content.firstChild.marks.some(
              (mark) => mark.type.name === "link"
            )
          ) {
            const matches = utils
              .getLinkify()
              .match(paste.content.firstChild.text);
            const isFullMatch =
              matches &&
              matches.length === 1 &&
              matches[0].raw === paste.content.firstChild.text;

            if (!isFullMatch) {
              return paste;
            }

            const marks = view.state.selection.$head.marks();
            const originalText = view.state.doc.textBetween(
              view.state.selection.from,
              view.state.selection.to
            );

            const textNode = view.state.schema.text(originalText, [
              ...marks,
              view.state.schema.marks.link.create({
                href: paste.content.firstChild.text,
              }),
            ]);
            paste = new Slice(Fragment.from(textNode), 0, 0);
          }
          return paste;
        },
      },
    }),
};

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
