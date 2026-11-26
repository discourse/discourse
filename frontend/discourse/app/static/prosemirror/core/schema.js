import OrderedMap from "orderedmap";
import { schema as defaultMarkdownSchema } from "prosemirror-markdown";
import { Schema } from "prosemirror-model";

// base nodes only authored through a markdown-it rule the host may disable
const RULE_NODES = { heading: "heading", horizontal_rule: "hr" };

/**
 * @param {import("discourse/lib/composer/rich-editor-extensions").RichEditorExtension[]} extensions
 * @param {boolean} [includeDefault]
 * @param {string[]} [markdownItRules] the host's rules, when it limits them
 */
export function createSchema(
  extensions,
  includeDefault = true,
  markdownItRules
) {
  let nodes = includeDefault
    ? defaultMarkdownSchema.spec.nodes
    : new OrderedMap([]);

  if (includeDefault && markdownItRules) {
    for (const [node, rule] of Object.entries(RULE_NODES)) {
      if (!markdownItRules.includes(rule)) {
        nodes = nodes.remove(node);
      }
    }
  }

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
