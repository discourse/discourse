import { schema } from "prosemirror-markdown";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    bullet_list: {
      ...schema.nodes.bullet_list.spec,

      // All we are doing here is overriding the tight list default to `true`.
      attrs: { tight: { default: true } },
    },
  },
};

export default extension;
