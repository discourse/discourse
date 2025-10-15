import { UnsupportedTokenError } from "discourse/static/prosemirror/core/parser";
import { i18n } from "discourse-i18n";

/** @type {RichEditorExtension} */
const extension = {
  plugins({
    pmState: { Plugin },
    pmModel: { Fragment, Slice },
    utils: { convertFromMarkdown, toggleRichEditor },
    schema,
    getContext,
  }) {
    return new Plugin({
      props: {
        clipboardTextParser(text) {
          try {
            const { content } = convertFromMarkdown(text);

            return Slice.maxOpen(Fragment.from(content));
          } catch (e) {
            if (e instanceof UnsupportedTokenError) {
              getContext().dialog.alert({
                message: i18n("composer.unsupported_token"),
                didConfirm: toggleRichEditor,
                didCancel: toggleRichEditor,
              });

              return new Fragment([
                schema.nodes.html_block.create({}, schema.text(text)),
              ]);
            }

            throw e;
          }
        },
      },
    });
  },
};

export default extension;
