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
    marks = spec.before
      ? marks.addBefore(spec.before, type, spec)
      : marks.update(type, spec);
  }

  return new Schema({ nodes, marks });
}

function extractNodes(extensions) {
  const nodes = {};
  for (const extension of extensions) {
    Object.assign(nodes, extension.nodeSpec);
  }
  return nodes;
}

function extractMarks(extensions) {
  const marks = {};
  for (const extension of extensions) {
    Object.assign(marks, extension.markSpec);
  }
  return marks;
}
