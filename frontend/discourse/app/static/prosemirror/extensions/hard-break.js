// @ts-check

import { schema } from "prosemirror-markdown";

/** @type {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension} */
const extension = {
  nodeSpec: {
    hard_break: {
      ...schema.nodes.hard_break.spec,
      linebreakReplacement: true,
    },
  },
};

export default extension;
