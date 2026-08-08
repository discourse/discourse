import { schemaFieldsForNodeOutput } from "./data-preview";
import { outputIndexForConnection } from "./expression-paths";
import { schemaFieldsForItems } from "./schema-fields";
import {
  inputConnectionsForNode,
  previousNodeForConnection,
  resolveDeclaredOutputSchemas,
} from "./schema-graph";

function flattenPaths(fields, prefix = "") {
  const result = [];

  for (const field of fields) {
    const path = prefix ? `${prefix}.${field.key}` : field.key;
    if (!field.key) {
      continue;
    }

    result.push({ path, type: field.type });

    if (field.children?.length) {
      result.push(...flattenPaths(field.children, path));
    }
  }

  return result;
}

/**
 * Dot paths available on a node's input items, relative to the item's json.
 *
 * Resolves from the declared output schema of upstream nodes, so paths are known
 * before the workflow has ever run; falls back to pinned or last-run items when a
 * node declares no schema.
 *
 * @param {object} node - the node being configured
 * @param {object} context - { nodes, connections, nodeTypes, session }
 * @returns {Array<{path: string, type: string}>} deduplicated, in declaration order
 */
export function inputFieldPathsForNode(node, context = {}) {
  if (!node) {
    return [];
  }

  const graph = {
    nodes: context.nodes || [],
    connections: context.connections || [],
    nodeTypes: context.nodeTypes || [],
  };
  const session = context.session;
  const runData = session?.lastExecutionRunData || {};
  const declaredOutputSchemas = resolveDeclaredOutputSchemas(graph);
  const seen = new Set();
  const paths = [];

  for (const connection of inputConnectionsForNode(node, graph)) {
    const previousNode = previousNodeForConnection(connection, graph);
    if (!previousNode) {
      continue;
    }

    const outputIndex = outputIndexForConnection(connection);
    const pinnedItems =
      outputIndex === 0
        ? session?.pinnedItemsForNode(previousNode.name)
        : undefined;

    const fields = pinnedItems
      ? schemaFieldsForItems(pinnedItems, { prefix: "" })
      : schemaFieldsForNodeOutput(runData, previousNode.name, {
          node: previousNode,
          outputIndex,
          prefix: "",
          graph,
          configuration: previousNode.parameters,
          declaredOutputSchemas,
        });

    for (const entry of flattenPaths(fields)) {
      if (seen.has(entry.path)) {
        continue;
      }
      seen.add(entry.path);
      paths.push(entry);
    }
  }

  return paths;
}
