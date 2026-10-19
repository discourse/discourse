const CODE_SELECTOR = "pre code";
const WORKFLOW_PREVIEW_KIND = "discourse_admin_assistant_workflow_preview_v1";
const MAX_PREVIEW_NODES = 24;
const MAX_PREVIEW_CONNECTIONS = 48;
const MAX_PREVIEW_OPERATIONS = 200;

function normalizeOperation(operation) {
  if (typeof operation !== "string") {
    return operation;
  }

  try {
    return JSON.parse(operation);
  } catch {
    return null;
  }
}

function nodeReference(operation, primary, fallback) {
  return operation[primary] ?? operation[fallback];
}

function stronglyConnectedComponents(nodes, connections) {
  const nodeIds = new Set(nodes.map((node) => node.id));
  const outgoing = new Map(nodes.map((node) => [node.id, []]));

  for (const connection of connections) {
    if (nodeIds.has(connection.from) && nodeIds.has(connection.to)) {
      outgoing.get(connection.from).push(connection.to);
    }
  }

  let nextIndex = 0;
  const components = [];
  const indexes = new Map();
  const lowLinks = new Map();
  const stack = [];
  const stacked = new Set();

  const visit = (nodeId) => {
    indexes.set(nodeId, nextIndex);
    lowLinks.set(nodeId, nextIndex);
    nextIndex++;
    stack.push(nodeId);
    stacked.add(nodeId);

    for (const targetId of outgoing.get(nodeId)) {
      if (!indexes.has(targetId)) {
        visit(targetId);
        lowLinks.set(
          nodeId,
          Math.min(lowLinks.get(nodeId), lowLinks.get(targetId))
        );
      } else if (stacked.has(targetId)) {
        lowLinks.set(
          nodeId,
          Math.min(lowLinks.get(nodeId), indexes.get(targetId))
        );
      }
    }

    if (lowLinks.get(nodeId) !== indexes.get(nodeId)) {
      return;
    }

    const component = [];
    let currentId;
    do {
      currentId = stack.pop();
      stacked.delete(currentId);
      component.push(currentId);
    } while (currentId !== nodeId);
    components.push(component);
  };

  for (const node of nodes) {
    if (!indexes.has(node.id)) {
      visit(node.id);
    }
  }

  return components;
}

function assignColumns(nodes, connections) {
  const components = stronglyConnectedComponents(nodes, connections);
  const componentByNode = new Map();
  components.forEach((component, componentIndex) => {
    component.forEach((nodeId) => componentByNode.set(nodeId, componentIndex));
  });

  const incoming = new Map(components.map((_, index) => [index, new Set()]));
  const outgoing = new Map(components.map((_, index) => [index, new Set()]));

  for (const connection of connections) {
    const source = componentByNode.get(connection.from);
    const target = componentByNode.get(connection.to);
    if (source === undefined || target === undefined || source === target) {
      continue;
    }
    outgoing.get(source).add(target);
    incoming.get(target).add(source);
  }

  const componentColumns = new Map();
  const queue = components
    .map((_, index) => index)
    .filter((index) => incoming.get(index).size === 0);

  while (queue.length) {
    const componentIndex = queue.shift();
    const column = componentColumns.get(componentIndex) ?? 0;

    for (const target of outgoing.get(componentIndex)) {
      componentColumns.set(
        target,
        Math.max(componentColumns.get(target) ?? 0, column + 1)
      );
      incoming.get(target).delete(componentIndex);
      if (incoming.get(target).size === 0) {
        queue.push(target);
      }
    }
  }

  return {
    columns: new Map(
      nodes.map((node) => [
        node.id,
        componentColumns.get(componentByNode.get(node.id)) ?? 0,
      ])
    ),
    hasCycle:
      components.some((component) => component.length > 1) ||
      connections.some((connection) => connection.from === connection.to),
  };
}

function graphFromOperations(operations) {
  const nodes = [];
  const nodesByReference = new Map();
  let nextNodeId = 0;
  let connections = [];

  const resolveNode = (reference) => nodesByReference.get(String(reference));

  for (const rawOperation of operations) {
    const operation = normalizeOperation(rawOperation);
    if (!operation || typeof operation !== "object") {
      return null;
    }

    switch (operation.op) {
      case "create_ai_agent":
      case "update_node_parameters":
        break;
      case "add_node": {
        const node = operation.node;
        if (!node || typeof node !== "object" || !node.name || !node.type) {
          return null;
        }

        const id = `node-${nextNodeId++}`;
        const previewNode = {
          id,
          name: String(node.name),
          type: String(node.type),
        };
        nodes.push(previewNode);
        nodesByReference.set(String(operation.client_id ?? id), previewNode);
        if (node.id) {
          nodesByReference.set(String(node.id), previewNode);
        }
        break;
      }
      case "rename_node": {
        const node = resolveNode(
          nodeReference(operation, "node_id", "client_id")
        );
        if (!node || !operation.name) {
          return null;
        }
        node.name = String(operation.name);
        break;
      }
      case "remove_node": {
        const node = resolveNode(
          nodeReference(operation, "node_id", "client_id")
        );
        if (!node) {
          return null;
        }
        nodes.splice(nodes.indexOf(node), 1);
        for (const [reference, referencedNode] of nodesByReference) {
          if (referencedNode === node) {
            nodesByReference.delete(reference);
          }
        }
        connections = connections.filter(
          (connection) =>
            connection.from !== node.id && connection.to !== node.id
        );
        break;
      }
      case "add_connection": {
        const source = resolveNode(
          nodeReference(operation, "from", "from_node_id")
        );
        const target = resolveNode(
          nodeReference(operation, "to", "to_node_id")
        );
        if (!source || !target) {
          return null;
        }
        connections.push({
          from: source.id,
          to: target.id,
          connectionType: String(operation.connection_type ?? "main"),
          outputIndex: Number(operation.output_index ?? 0),
          inputIndex: Number(operation.input_index ?? 0),
        });
        break;
      }
      case "remove_connection": {
        const source = resolveNode(
          nodeReference(operation, "from", "from_node_id")
        );
        const target = resolveNode(
          nodeReference(operation, "to", "to_node_id")
        );
        if (!source || !target) {
          return null;
        }
        connections = connections.filter((connection) => {
          if (connection.from !== source.id || connection.to !== target.id) {
            return true;
          }
          if (
            operation.output_index !== undefined &&
            connection.outputIndex !== Number(operation.output_index)
          ) {
            return true;
          }
          return (
            operation.input_index !== undefined &&
            connection.inputIndex !== Number(operation.input_index)
          );
        });
        break;
      }
      default:
        return null;
    }
  }

  if (!nodes.length) {
    return null;
  }

  return { nodes, connections };
}

export function extractWorkflowPreview(cooked) {
  if (!cooked || typeof DOMParser === "undefined") {
    return null;
  }

  const document = new DOMParser().parseFromString(cooked, "text/html");
  const code = document.querySelector(CODE_SELECTOR);
  if (!code) {
    return null;
  }

  try {
    const payload = JSON.parse(code.textContent);
    if (payload?.kind !== WORKFLOW_PREVIEW_KIND) {
      return null;
    }
    const configuration = payload.configuration;
    if (
      !configuration ||
      typeof configuration.name !== "string" ||
      !Array.isArray(configuration.operations)
    ) {
      return null;
    }
    if (configuration.operations.length > MAX_PREVIEW_OPERATIONS) {
      return { name: configuration.name, configuration, unavailable: true };
    }

    const graph = graphFromOperations(configuration.operations);
    if (!graph) {
      return { name: configuration.name, configuration, unavailable: true };
    }
    if (
      graph.nodes.length > MAX_PREVIEW_NODES ||
      graph.connections.length > MAX_PREVIEW_CONNECTIONS
    ) {
      return {
        name: configuration.name,
        configuration,
        nodeCount: graph.nodes.length,
        unavailable: true,
      };
    }

    return { name: configuration.name, configuration, ...graph };
  } catch {
    return null;
  }
}

export function layoutWorkflowPreview(preview) {
  const nodeWidth = 176;
  const nodeHeight = 96;
  const horizontalGap = 32;
  const verticalGap = 28;
  const padding = 20;
  const { columns, hasCycle } = assignColumns(
    preview.nodes,
    preview.connections
  );
  const rowsByColumn = new Map();

  for (const node of preview.nodes) {
    const column = columns.get(node.id);
    const columnNodes = rowsByColumn.get(column) ?? [];
    columnNodes.push(node);
    rowsByColumn.set(column, columnNodes);
  }

  const positionedNodes = preview.nodes.map((node) => {
    const column = columns.get(node.id);
    const row = rowsByColumn.get(column).indexOf(node);
    return {
      ...node,
      x: padding + column * (nodeWidth + horizontalGap),
      y: padding + row * (nodeHeight + verticalGap),
    };
  });
  const positionedById = new Map(
    positionedNodes.map((node) => [node.id, node])
  );
  const maxColumn = Math.max(...columns.values());
  const maxRows = Math.max(
    ...[...rowsByColumn.values()].map((nodes) => nodes.length)
  );
  const width =
    padding * 2 + (maxColumn + 1) * nodeWidth + maxColumn * horizontalGap;
  const height =
    padding * 2 + maxRows * nodeHeight + (maxRows - 1) * verticalGap;

  const connections = preview.connections.map((connection, index) => {
    const sourceOutputIndexes = new Set(
      preview.connections
        .filter((candidate) => candidate.from === connection.from)
        .map((candidate) => candidate.outputIndex)
    );
    const branchNumber =
      sourceOutputIndexes.size > 1 ? connection.outputIndex + 1 : null;
    const source = positionedById.get(connection.from);
    const target = positionedById.get(connection.to);
    const startX = source.x + nodeWidth;
    const startY = source.y + nodeHeight / 2;
    const endX = target.x;
    const endY = target.y + nodeHeight / 2;
    let path;
    let labelX = (startX + endX) / 2;
    let labelY = (startY + endY) / 2 - 8;

    if (endX > startX) {
      const controlOffset = Math.max(28, (endX - startX) / 2);
      path = `M ${startX} ${startY} C ${startX + controlOffset} ${startY}, ${endX - controlOffset} ${endY}, ${endX} ${endY}`;
    } else {
      const loopOffset = 22 + (index % 4) * 8;
      const bottom = Math.max(startY, endY) + nodeHeight / 2 + loopOffset;
      labelX = (startX + endX) / 2;
      labelY = bottom - 6;
      path = `M ${startX} ${startY} C ${startX + loopOffset} ${startY}, ${startX + loopOffset} ${bottom}, ${startX} ${bottom} L ${endX - loopOffset} ${bottom} C ${endX - loopOffset * 2} ${bottom}, ${endX - loopOffset * 2} ${endY}, ${endX} ${endY}`;
    }

    return { ...connection, branchNumber, labelX, labelY, path };
  });

  return {
    connections,
    hasCycle,
    height,
    nodes: positionedNodes,
    nodeHeight,
    nodeWidth,
    width,
  };
}
