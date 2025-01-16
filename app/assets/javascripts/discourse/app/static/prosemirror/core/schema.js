import OrderedMap from "orderedmap";
import { schema as defaultMarkdownSchema } from "prosemirror-markdown";
import { Schema } from "prosemirror-model";

export function createSchema(extensions, includeDefault = true) {
  let nodes = includeDefault
    ? defaultMarkdownSchema.spec.nodes
    : new OrderedMap([]);

  let marks = includeDefault
    ? defaultMarkdownSchema.spec.marks
    : new OrderedMap([]);

  for (const [type, spec] of Object.entries(extractNodes(extensions))) {
    nodes = nodes.update(type, spec);
  }

  for (const [type, spec] of Object.entries(extractMarks(extensions))) {
    marks = marks.update(type, spec);
  }

  return new Schema({ nodes, marks });
}

function extractNodes(extensions) {
  return extensions.reduce((acc, { nodeSpec }) => {
    Object.assign(acc, nodeSpec);
    return acc;
  }, {});
}

function extractMarks(extensions) {
  return extensions.reduce((acc, { markSpec }) => {
    Object.assign(acc, markSpec);
    return acc;
  }, {});
}
