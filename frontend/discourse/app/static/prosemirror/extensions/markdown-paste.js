/** @type {RichEditorExtension} */
const extension = {
  plugins({
    pmState: { Plugin },
    pmModel: { Fragment, Slice },
    utils: { convertFromMarkdown },
  }) {
    return new Plugin({
      props: {
        clipboardTextParser(text) {
          const doc = convertFromMarkdown(text);
          return Slice.maxOpen(Fragment.from(doc.content));
        },
      },
    });
  },
};

export default extension;
