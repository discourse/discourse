import {
  normalizeSourceOutputIndex,
  normalizeTargetInputIndex,
  portIndexFromKey,
} from "../lib/workflows/graph-constants";

export default class WorkflowConnection {
  static create(args = {}) {
    return new WorkflowConnection(args);
  }

  static serialize(connection) {
    return {
      sourceClientId: connection.sourceClientId,
      targetClientId: connection.targetClientId,
      connectionType: connection.connectionType || "main",
      sourceOutputIndex: normalizeSourceOutputIndex(connection),
      targetInputIndex: normalizeTargetInputIndex(connection),
    };
  }

  constructor(args = {}) {
    this.sourceClientId = args.sourceClientId;
    this.targetClientId = args.targetClientId;
    this.sourceOutput = args.sourceOutput ?? "main";
    this.targetInput = args.targetInput ?? "main";
    this.connectionType = args.connectionType ?? "main";
    this.sourceOutputIndex =
      args.sourceOutputIndex ?? portIndexFromKey(this.sourceOutput);
    this.targetInputIndex =
      args.targetInputIndex ?? portIndexFromKey(this.targetInput);
  }
}

export function serializeConnections(connections, nodes) {
  const nodesByClientId = new Map(nodes.map((node) => [node.clientId, node]));

  return (connections || []).reduce((result, connection) => {
    const sourceNode = nodesByClientId.get(connection.sourceClientId);
    const targetNode = nodesByClientId.get(connection.targetClientId);

    if (!sourceNode || !targetNode) {
      return result;
    }

    const connectionType = connection.connectionType || "main";
    const sourceOutputIndex = normalizeSourceOutputIndex(connection);
    const targetInputIndex = normalizeTargetInputIndex(connection);

    result[sourceNode.name] ||= {};
    result[sourceNode.name][connectionType] ||= [];
    while (
      result[sourceNode.name][connectionType].length <= sourceOutputIndex
    ) {
      result[sourceNode.name][connectionType].push([]);
    }
    result[sourceNode.name][connectionType][sourceOutputIndex].push({
      node: targetNode.name,
      type: connectionType,
      index: targetInputIndex,
    });

    return result;
  }, {});
}

export function deserializeConnections(connections, nodes) {
  const nodesByName = new Map(nodes.map((node) => [node.name, node]));
  const result = [];

  for (const [sourceName, outputsByType] of Object.entries(connections || {})) {
    const sourceNode = nodesByName.get(sourceName);

    if (!sourceNode || !outputsByType) {
      continue;
    }

    for (const [connectionType, outputConnections] of Object.entries(
      outputsByType
    )) {
      (outputConnections || []).forEach(
        (targetConnections, sourceOutputIndex) => {
          (targetConnections || []).forEach((targetConnection) => {
            const targetNode = nodesByName.get(targetConnection.node);

            if (!targetNode) {
              return;
            }

            result.push(
              WorkflowConnection.create({
                sourceClientId: sourceNode.clientId,
                targetClientId: targetNode.clientId,
                connectionType,
                sourceOutputIndex,
                targetInputIndex: targetConnection.index || 0,
              })
            );
          });
        }
      );
    }
  }

  return result;
}
