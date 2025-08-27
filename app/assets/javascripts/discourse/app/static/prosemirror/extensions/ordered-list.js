import { schema } from "prosemirror-markdown";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    ordered_list: {
      ...schema.nodes.ordered_list.spec,

      // All we are doing here is overriding the tight list default to `true`.
      attrs: { order: { default: 1 }, tight: { default: true } },
    },
  },
};

export default extension;
