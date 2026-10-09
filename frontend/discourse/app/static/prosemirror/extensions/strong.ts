import { schema } from "prosemirror-markdown";
import type { Mark } from "prosemirror-model";
import type { RichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";

const extension: RichEditorExtension = {
  markSpec: {
    strong: {
      ...schema.marks.strong.spec,
      parseDOM: [
        { tag: "strong" },
        {
          tag: "b",
          getAttrs: (node: HTMLElement) =>
            node.style.fontWeight !== "normal" && null,
        },
        {
          style: "font-weight=400",
          clearMark: (m: Mark) => m.type.name === "strong",
        },
        {
          // a copied page inlines theme weights; 500 is CSS medium, not authored bold
          style: "font-weight",
          getAttrs: (value: string) => {
            const weight = Number.parseFloat(value);
            return (
              (/^bold(er)?$/.test(value) ||
                (weight >= 600 && weight <= 1000)) &&
              null
            );
          },
        },
      ],
    },
  },
};

export default extension;
