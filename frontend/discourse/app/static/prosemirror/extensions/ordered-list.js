import { schema } from "prosemirror-markdown";
import { isListTight } from "discourse/lib/list-utils";

/** @type {RichEditorExtension} */
const extension = {
  nodeSpec: {
    ordered_list: {
      ...schema.nodes.ordered_list.spec,

      attrs: { order: { default: 1 }, tight: { default: true } },
      parseDOM: [
        {
          tag: "ol",
          getAttrs(dom) {
            return {
              order: dom.hasAttribute("start") ? +dom.getAttribute("start") : 1,
              tight: dom.hasAttribute("data-tight") || isListTight(dom),
            };
          },
        },
      ],
    },
  },
};

export default extension;
