// @ts-check

import codemark from "prosemirror-codemark";

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  plugins({ schema }) {
    return codemark({ markType: schema.marks.code });
  },
};

export default extension;
