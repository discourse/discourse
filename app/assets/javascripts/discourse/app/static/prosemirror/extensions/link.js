export default {
  inputRules: [
    // []() replacement
    ({ schema, markInputRule }) =>
      markInputRule(
        /\[([^\]]+)]\(([^)\s]+)(?:\s+[“"']([^“"']+)[”"'])?\)$/,
        schema.marks.link,
        (match) => {
          return { href: match[2], title: match[3] };
        }
      ),
    // TODO(renato): auto-linkify when typing (https://github.com/markdown-it/markdown-it/blob/master/lib/rules_inline/autolink.mjs)
  ],
  plugins: ({ Plugin, Slice, Fragment }) =>
    new Plugin({
      props: {
        // Auto-linkify plain-text pasted URLs
        // TODO(renato): URLs copied from HTML will go through the regular HTML parsing
        //  it would be nice to auto-linkify them too
        clipboardTextParser(text, $context, plain, view) {
          // TODO(renato): a less naive regex, reuse existing
          if (!text.match(/^https?:\/\//) || view.state.selection.empty) {
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
      },
    }),
};
