import codemark from "prosemirror-codemark";
import type { RichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";

const extension: RichEditorExtension = {
  markdownItRules: ["backticks"],
  plugins({ schema }) {
    return codemark({ markType: schema.marks.code });
  },
};

export default extension;
