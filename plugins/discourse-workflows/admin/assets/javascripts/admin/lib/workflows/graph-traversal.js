import resolveNodeFields, { fieldsFromSchema } from "./resolve-node-fields";

export function findPreviousNode(node, graph, visited) {
  if (visited.has(node.clientId)) {
    return null;
  }
  visited.add(node.clientId);

  const incoming = graph.connections.find(
    (c) =>
      c.targetClientId === node.clientId &&
      c.sourceClientId !== node.clientId &&
      !visited.has(c.sourceClientId)
  );
  if (!incoming) {
    return null;
  }

  return (
    graph.nodes.find((n) => n.clientId === incoming.sourceClientId) || null
  );
}

export function resolveFieldsForNode(node, graph) {
  if (node.type?.startsWith("condition:")) {
    return null;
  }

  const configFields = resolveNodeFields(node, graph.nodeTypes);
  if (configFields?.length) {
    return configFields;
  }

  if (node.type?.startsWith("trigger:")) {
    const triggerType = graph.nodeTypes.find(
      (nt) => nt.identifier === node.type
    );
    return fieldsFromSchema(triggerType?.output_schema) || null;
  }

  return null;
}

export function resolvePreviousOutput(node, graph, visited = new Set()) {
  const previousNode = findPreviousNode(node, graph, visited);
  if (!previousNode) {
    return [];
  }

  const fields = resolveFieldsForNode(previousNode, graph);
  if (fields) {
    return fields;
  }

  return resolvePreviousOutput(previousNode, graph, visited);
}

export function resolveAllAncestors(node, graph, visited = new Set()) {
  const prevNode = findPreviousNode(node, graph, visited);
  if (!prevNode) {
    return [];
  }

  const result = [];

  const fields = resolveFieldsForNode(prevNode, graph);
  if (fields) {
    result.push({ node: prevNode, fields });
  }

  result.push(...resolveAllAncestors(prevNode, graph, visited));

  return result;
}
