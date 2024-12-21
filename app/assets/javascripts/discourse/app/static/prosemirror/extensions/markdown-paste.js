import { convertFromMarkdown } from "../lib/parser";

/** @type {RichEditorExtension} */
const extension = {
  plugins({ pmState: { Plugin }, pmModel: { Fragment, Slice } }) {
    return new Plugin({
      props: {
        clipboardTextParser(text, $context, plain, view) {
          const { content } = convertFromMarkdown(view.state.schema, text);

          return Slice.maxOpen(Fragment.from(content));
        },
      },
    });
  },
};

export default extension;
