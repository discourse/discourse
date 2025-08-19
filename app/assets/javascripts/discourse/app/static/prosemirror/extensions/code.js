import codemark from "prosemirror-codemark";

/** @type {RichEditorExtension} */
const extension = {
  plugins({ schema }) {
    return codemark({ markType: schema.marks.code });
  },
};

export default extension;
