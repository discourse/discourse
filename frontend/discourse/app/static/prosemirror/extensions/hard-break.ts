import { schema } from "prosemirror-markdown";
import type { RichEditorExtension } from "discourse/lib/composer/rich-editor-extensions";

const extension: RichEditorExtension = {
  nodeSpec: {
    hard_break: {
      ...schema.nodes.hard_break.spec,
      linebreakReplacement: true,
    },
  },
};

export default extension;
