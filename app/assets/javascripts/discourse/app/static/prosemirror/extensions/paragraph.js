// @ts-check
import { schema } from "prosemirror-markdown";

const PRE_STYLE_VALUES = ["pre", "pre-wrap", "pre-line"];

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeSpec: {
    paragraph: {
      ...schema.nodes.paragraph.spec,
      parseDOM: [
        { tag: "p" },
        {
          tag: "*",
          preserveWhitespace: "full",
          consuming: false,
          getAttrs(node) {
            return PRE_STYLE_VALUES.includes(node.style.whiteSpace)
              ? false
              : null;
          },
        },
      ],
    },
  },
};

export default extension;
