/** @type {RichEditorExtension} */
const extension = {
  plugins({ pmState: { Plugin }, pmModel: { Fragment, Slice } }) {
    return new Plugin({
      props: {
        clipboardTextParser(text, $context, plain, view) {
          const { content } = view.props.convertFromMarkdown(text);

          return Slice.maxOpen(Fragment.from(content));
        },
      },
    });
  },
};

export default extension;
