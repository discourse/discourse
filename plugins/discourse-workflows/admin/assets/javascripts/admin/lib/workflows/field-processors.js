import { findPreviousNode, resolveFieldsForNode } from "./graph-traversal";

function collectAncestorFormDataChildren(node, graph, visited = new Set()) {
  const prevNode = findPreviousNode(node, graph, visited);
  if (!prevNode) {
    return [];
  }

  const children = [];
  const fields = resolveFieldsForNode(prevNode, graph);
  if (fields) {
    const formData = fields.find((f) => f.key === "form_data" && f.children);
    if (formData) {
      children.push(...formData.children);
    }
  }

  children.push(...collectAncestorFormDataChildren(prevNode, graph, visited));

  return children;
}

function accumulateFormData(fields, node, graph) {
  const formDataField = fields.find((f) => f.key === "form_data" && f.children);
  if (!formDataField) {
    return fields;
  }

  const ancestorChildren = collectAncestorFormDataChildren(node, graph);
  if (!ancestorChildren.length) {
    return fields;
  }

  const ownKeys = new Set(formDataField.children.map((c) => c.key));
  const extra = ancestorChildren.filter((c) => !ownKeys.has(c.key));

  return fields.map((f) =>
    f === formDataField ? { ...f, children: [...extra, ...f.children] } : f
  );
}

const PROCESSORS = [accumulateFormData];

export default function processFields(fields, node, graph) {
  return PROCESSORS.reduce(
    (result, processor) => processor(result, node, graph),
    fields
  );
}
