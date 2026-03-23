import { NODE_HEIGHT_WITH_DESC } from "../../../lib/workflows/node-utils";
import { buildOutgoingIndex } from "./graph-utils";

const COLUMN_GAP = 100;
const ROW_GAP = 80;
const NODE_HEIGHT = NODE_HEIGHT_WITH_DESC;
const START_X = 50;
const START_Y = 200;

function findBackEdges(connections) {
  const backEdges = new Set();

  for (const conn of connections) {
    if (conn.sourceClientId === conn.targetClientId) {
      backEdges.add(conn);
    }
  }

  // Detect multi-node cycles via DFS
  const adj = buildOutgoingIndex(
    connections.filter((c) => !backEdges.has(c)),
    "sourceClientId"
  );
  const visiting = new Set();
  const visited = new Set();

  function dfs(nodeId) {
    if (visiting.has(nodeId)) {
      return nodeId;
    }
    if (visited.has(nodeId)) {
      return null;
    }
    visiting.add(nodeId);
    for (const conn of adj.get(nodeId) || []) {
      const cycleNode = dfs(conn.targetClientId);
      if (cycleNode !== null) {
        if (conn.targetClientId === cycleNode) {
          backEdges.add(conn);
        }
        return visiting.has(cycleNode) ? cycleNode : null;
      }
    }
    visiting.delete(nodeId);
    visited.add(nodeId);
    return null;
  }

  for (const conn of connections) {
    if (!visited.has(conn.sourceClientId)) {
      dfs(conn.sourceClientId);
    }
  }

  return backEdges;
}

function assignLayers(nodes, connections) {
  const backEdges = findBackEdges(connections);
  const adj = buildOutgoingIndex(
    connections.filter((c) => !backEdges.has(c)),
    "sourceClientId"
  );
  const trigger = nodes.find((n) => n.type?.startsWith("trigger:"));

  if (!trigger) {
    return new Map(nodes.map((n, i) => [n.clientId, i]));
  }

  const layers = new Map();
  const queue = [{ id: trigger.clientId, layer: 0 }];
  layers.set(trigger.clientId, 0);

  let head = 0;
  while (head < queue.length) {
    const { id, layer } = queue[head++];

    for (const conn of adj.get(id) || []) {
      const targetLayer = layer + 1;
      const current = layers.get(conn.targetClientId);

      if (current === undefined || targetLayer > current) {
        layers.set(conn.targetClientId, targetLayer);
        queue.push({ id: conn.targetClientId, layer: targetLayer });
      }
    }
  }

  // Assign unconnected nodes to layer 0
  for (const node of nodes) {
    if (!layers.has(node.clientId)) {
      layers.set(node.clientId, 0);
    }
  }

  return layers;
}

function groupByLayer(nodes, layerMap) {
  const groups = new Map();
  for (const node of nodes) {
    const layer = layerMap.get(node.clientId) ?? 0;
    const list = groups.get(layer);
    if (list) {
      list.push(node);
    } else {
      groups.set(layer, [node]);
    }
  }
  return groups;
}

function orderWithinLayer(layerNodes, connections) {
  // For condition branches: sort "true" targets above "false" targets
  const orderHints = new Map();
  for (const conn of connections) {
    if (conn.sourceOutput === "true") {
      orderHints.set(conn.targetClientId, -1);
    } else if (conn.sourceOutput === "false") {
      orderHints.set(conn.targetClientId, 1);
    }
  }

  return [...layerNodes].sort(
    (a, b) =>
      (orderHints.get(a.clientId) ?? 0) - (orderHints.get(b.clientId) ?? 0)
  );
}

export default function autoLayout(nodes, connections) {
  if (!nodes?.length) {
    return [];
  }

  const layerMap = assignLayers(nodes, connections);
  const groups = groupByLayer(nodes, layerMap);
  const maxLayer = Math.max(...groups.keys());
  const positions = new Map();

  for (let layer = 0; layer <= maxLayer; layer++) {
    const layerNodes = groups.get(layer) || [];
    const ordered = orderWithinLayer(layerNodes, connections);
    const totalHeight =
      ordered.length * NODE_HEIGHT + (ordered.length - 1) * ROW_GAP;
    const startY = START_Y - totalHeight / 2;

    for (let i = 0; i < ordered.length; i++) {
      positions.set(ordered[i].clientId, {
        x: START_X + layer * COLUMN_GAP,
        y: startY + i * (NODE_HEIGHT + ROW_GAP),
      });
    }
  }

  return nodes.map((node) => ({
    ...node,
    position: node.position ??
      positions.get(node.clientId) ?? { x: START_X, y: START_Y },
  }));
}
