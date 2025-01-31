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
          const { content } = convertFromMarkdown(text);

          return Slice.maxOpen(Fragment.from(content));
        },
      },
    });
  },
};

export default extension;
