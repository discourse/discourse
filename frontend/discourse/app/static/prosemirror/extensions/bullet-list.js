import { schema } from "prosemirror-markdown";
import { isListTight } from "discourse/lib/list-utils";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    bullet_list: {
      ...schema.nodes.bullet_list.spec,

      attrs: { tight: { default: true } },
      parseDOM: [
        {
          tag: "ul",
          getAttrs(dom) {
            return {
              tight: dom.hasAttribute("data-tight") || isListTight(dom),
            };
          },
        },
      ],
    },
  },
};

export default extension;
