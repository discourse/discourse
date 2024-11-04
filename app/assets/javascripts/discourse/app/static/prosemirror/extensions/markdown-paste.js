import { convertFromMarkdown } from "../lib/parser";

export default {
  plugins({ Plugin, Fragment, Slice }) {
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
