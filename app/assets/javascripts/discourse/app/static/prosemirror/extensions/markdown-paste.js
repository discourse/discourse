/** @type {RichEditorExtension} */
const extension = {
  plugins({
    pmState: { Plugin },
    pmModel: { Fragment, Slice },
    utils: { convertFromMarkdown },
  }) {
    return new Plugin({
      props: {
        clipboardTextParser(text, $context, plain, view) {
          const content = convertFromMarkdown(text);
          console.log(
            "text: ",
            text,
            "convertedFromMD: ",
            content,
            "fragment: ",
            Fragment.from(content.content)
          );

          return Slice.maxOpen(Fragment.from(content.content));
        },
      },
    });
  },
};

export default extension;
