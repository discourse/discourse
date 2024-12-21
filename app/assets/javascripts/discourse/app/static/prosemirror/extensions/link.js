const markdownUrlInputRule = ({ schema, markInputRule }) =>
  markInputRule(
    /\[([^\]]+)]\(([^)\s]+)(?:\s+[“"']([^“"']+)[”"'])?\)$/,
    schema.marks.link,
    (match) => {
      return { href: match[2], title: match[3] };
    }
  );

export default {
  markSpec: {
    link: {
      attrs: {
        href: {},
        title: { default: null },
        autoLink: { default: null },
        attachment: { default: null },
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
        };
      },
    },
  },
  inputRules: [markdownUrlInputRule],
  plugins: ({
    Plugin,
    Slice,
    Fragment,
    undoDepth,
    ReplaceAroundStep,
    ReplaceStep,
    AddMarkStep,
    RemoveMarkStep,
    utils,
  }) =>
    new Plugin({
      // Auto-linkify typed URLs
      appendTransaction: (transactions, prevState, state) => {
        const isUndo = undoDepth(prevState) - undoDepth(state) === 1;
        if (isUndo) {
          return;
        }

        const docChanged = transactions.some(
          (transaction) => transaction.docChanged
        );
        if (!docChanged) {
          return;
        }

        const composedTransaction = utils.composeSteps(transactions, prevState);
        const changes = utils.getChangedRanges(
          composedTransaction,
          [ReplaceAroundStep, ReplaceStep],
          [AddMarkStep, ReplaceAroundStep, ReplaceStep, RemoveMarkStep]
        );
        const { mapping } = composedTransaction;
        const { tr, doc } = state;

        for (const { prevFrom, prevTo, from, to } of changes) {
          utils
            .findTextBlocksInRange(doc, { from, to })
            .forEach(({ text, positionStart }) => {
              const matches = utils.getLinkify().match(text);
              if (!matches) {
                return;
              }

              for (const match of matches) {
                const { index, lastIndex, raw } = match;
                const start = positionStart + index;
                const end = positionStart + lastIndex + 1;
                const href = raw;
                // TODO not ready yet
                // tr.setMeta("autolinking", true).addMark(
                //   start,
                //   end,
                //   state.schema.marks.link.create({ href })
                // );
              }
            });
        }

        return tr;
      },
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
