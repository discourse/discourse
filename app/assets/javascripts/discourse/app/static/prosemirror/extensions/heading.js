import { schema } from "prosemirror-markdown";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    heading: {
      ...schema.nodes.heading.spec,
      content: "inline*",
    },
  },
};

export default extension;
