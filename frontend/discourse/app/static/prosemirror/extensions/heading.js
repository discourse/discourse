import { schema } from "prosemirror-markdown";

/** @type {RichEditorExtension} */
const extension = {
  markdownItRules: ["heading"],
  nodeSpec: {
    heading: {
      ...schema.nodes.heading.spec,
      content: "inline*",
    },
  },
};

export default extension;
