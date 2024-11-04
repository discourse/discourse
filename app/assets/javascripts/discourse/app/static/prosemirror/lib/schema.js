import { schema as defaultMarkdownSchema } from "prosemirror-markdown";
import { Schema } from "prosemirror-model";
import {
  getMarks,
  getNodes,
} from "discourse/lib/composer/rich-editor-extensions";

export function createSchema() {
  let nodes = defaultMarkdownSchema.spec.nodes;
  let marks = defaultMarkdownSchema.spec.marks;

  for (const [type, spec] of Object.entries(getNodes())) {
    nodes = nodes.addToEnd(type, spec);
  }

  for (const [type, spec] of Object.entries(getMarks())) {
    marks = marks.addToEnd(type, spec);
  }

  return new Schema({ nodes, marks });
}
