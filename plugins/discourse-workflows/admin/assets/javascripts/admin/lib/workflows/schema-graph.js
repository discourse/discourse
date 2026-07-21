import {
  normalizeSourceOutputIndex,
  normalizeTargetInputIndex,
} from "./graph-constants";
import { resolveNodeTypeVersion, typeVersionForNode } from "./node-types";
import { fieldVisible } from "./property-engine";

const DRAFT_URI = "https://json-schema.org/draft/2020-12/schema";

function isUnknown(schema) {
  return !schema || !Object.keys(schema).length;
}

function isAnyOfWrapper(schema) {
  const keys = Object.keys(schema).filter((key) => key !== "$schema");
  return keys.length === 1 && keys[0] === "anyOf";
}

function anyOfBranches(schema) {
  return isAnyOfWrapper(schema) ? schema.anyOf : [schema];
}

function schemasEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function unionSchemas(schemas) {
  if (!schemas.length || schemas.some(isUnknown)) {
    return {};
  }

  const branches = [];
  for (const schema of schemas) {
    for (const branch of anyOfBranches(schema)) {
      if (!branches.some((existing) => schemasEqual(existing, branch))) {
        branches.push(branch);
      }
    }
  }

  return branches.length === 1
    ? branches[0]
    : { $schema: DRAFT_URI, anyOf: branches };
}

function isObjectSchema(schema) {
  const types = Array.isArray(schema.type)
    ? schema.type
    : schema.type
      ? [schema.type]
      : [];
  return types.includes("object");
}

function overlaySchemas(inputSchema, declaredSchema) {
  if (isUnknown(inputSchema)) {
    return declaredSchema;
  }

  if (isUnknown(declaredSchema)) {
    return inputSchema;
  }

  if (isAnyOfWrapper(inputSchema)) {
    return unionSchemas(
      inputSchema.anyOf.map((branch) => overlaySchemas(branch, declaredSchema))
    );
  }

  const merged = { ...inputSchema, ...declaredSchema };
  if (isObjectSchema(inputSchema) && isObjectSchema(declaredSchema)) {
    merged.properties = {
      ...(inputSchema.properties || {}),
      ...(declaredSchema.properties || {}),
    };

    const required = [
      ...new Set([
        ...(inputSchema.required || []),
        ...(declaredSchema.required || []),
      ]),
    ];
    if (required.length) {
      merged.required = required;
    } else {
      delete merged.required;
    }
  }

  return merged;
}

function resolvedOutputSchema(contract, inputSchema = {}) {
  switch (contract.mode) {
    case "passthrough":
      return inputSchema;
    case "union":
      return unionSchemas([inputSchema, contract.schema]);
    case "merge":
      return overlaySchemas(inputSchema, contract.schema);
    default:
      return contract.schema;
  }
}

function contractDefinition(contract = {}) {
  return {
    mode: contract.mode ?? "replace",
    schema:
      contract.schema &&
      typeof contract.schema === "object" &&
      !Array.isArray(contract.schema)
        ? contract.schema
        : {},
  };
}

function activeOutputContract(contract, configuration) {
  const variant = (contract.variants || []).find((candidate) =>
    fieldVisible({ display_options: candidate.display_options }, configuration)
  );
  if (variant) {
    return variant;
  }

  return fieldVisible(
    { display_options: contract.display_options },
    configuration
  )
    ? contract
    : {};
}

function nodeTypeDefinitionForNode(node, graph) {
  const definition = (graph?.nodeTypes || []).find(
    (candidate) =>
      candidate.name === node?.type || candidate.identifier === node?.type
  );
  if (!definition) {
    return null;
  }

  return resolveNodeTypeVersion(definition, typeVersionForNode(node));
}

function ownOutputContracts(node, graph, configuration) {
  const definition = nodeTypeDefinitionForNode(node, graph);
  if (!definition) {
    return [{ mode: "replace", schema: {} }];
  }

  const currentConfiguration = configuration ?? node.configuration ?? {};
  const serializedContracts = definition.output_contracts;
  const contracts = Array.isArray(serializedContracts)
    ? serializedContracts
    : [];
  const outputCount =
    contracts.length ||
    (definition.outputs || definition.ports || [null]).length;

  return Array.from({ length: outputCount }, (_, index) =>
    contractDefinition(
      activeOutputContract(contracts[index] || {}, currentConfiguration)
    )
  );
}

function nodeKey(node) {
  return node?.clientId ?? node?.id ?? node;
}

function connectionOrder(left, right) {
  return (
    normalizeTargetInputIndex(left) - normalizeTargetInputIndex(right) ||
    normalizeSourceOutputIndex(left) - normalizeSourceOutputIndex(right) ||
    String(left.sourceClientId).localeCompare(String(right.sourceClientId))
  );
}

export function resolveDeclaredOutputSchemas(
  graph,
  { configurationOverrides = new Map(), visited = new Set() } = {}
) {
  const nodes = (graph?.nodes || []).filter(
    (candidate) => !visited.has(nodeKey(candidate))
  );
  const nodesById = new Map(
    nodes.map((candidate) => [nodeKey(candidate), candidate])
  );

  const incomingByTarget = new Map();
  for (const connection of graph?.connections || []) {
    if (
      connection.sourceClientId === connection.targetClientId ||
      visited.has(connection.sourceClientId) ||
      !nodesById.has(connection.sourceClientId) ||
      !nodesById.has(connection.targetClientId)
    ) {
      continue;
    }

    const incoming = incomingByTarget.get(connection.targetClientId) || [];
    incoming.push(connection);
    incomingByTarget.set(connection.targetClientId, incoming);
  }
  for (const incoming of incomingByTarget.values()) {
    incoming.sort(connectionOrder);
  }

  const contractsByKey = new Map(
    nodes.map((candidate) => [
      nodeKey(candidate),
      ownOutputContracts(
        candidate,
        graph,
        configurationOverrides.get(nodeKey(candidate))
      ),
    ])
  );

  const outputSchemas = new Map();

  function inputSchemaFor(key) {
    const connections = incomingByTarget.get(key) || [];
    if (!connections.length) {
      return {};
    }

    const schemas = [];
    for (const connection of connections) {
      const sourceOutputs = outputSchemas.get(connection.sourceClientId);
      if (!sourceOutputs) {
        continue;
      }

      schemas.push(sourceOutputs[normalizeSourceOutputIndex(connection)] || {});
    }

    return schemas.length ? unionSchemas(schemas) : undefined;
  }

  function sweepUntilStable() {
    let changed = true;
    let sweeps = 0;

    while (changed) {
      if (++sweeps > nodes.length + 2) {
        throw new Error("Output schema graph did not converge");
      }

      changed = false;
      for (const candidate of nodes) {
        const key = nodeKey(candidate);
        const contracts = contractsByKey.get(key);
        let inputSchema = {};

        if (contracts.some(({ mode }) => mode !== "replace")) {
          inputSchema = inputSchemaFor(key);
          if (inputSchema === undefined) {
            continue;
          }
        }

        const resolved = contracts.map((contract) =>
          resolvedOutputSchema(contract, inputSchema)
        );
        if (
          !outputSchemas.has(key) ||
          !schemasEqual(outputSchemas.get(key), resolved)
        ) {
          changed = true;
          outputSchemas.set(key, resolved);
        }
      }
    }
  }

  sweepUntilStable();

  let promoted = false;
  for (const candidate of nodes) {
    const key = nodeKey(candidate);
    if (!outputSchemas.has(key)) {
      promoted = true;
      outputSchemas.set(
        key,
        contractsByKey.get(key).map(() => ({}))
      );
    }
  }
  if (promoted) {
    sweepUntilStable();
  }

  return outputSchemas;
}

export function outputSchemaForNode(
  node,
  graph,
  { configuration, outputIndex = 0, outputSchemas, visited = new Set() } = {}
) {
  if (!node) {
    return {};
  }

  const targetNodeKey = nodeKey(node);
  if (visited.has(targetNodeKey)) {
    return {};
  }

  if (!outputSchemas) {
    const nodes = graph?.nodes || [];
    const resolutionGraph = nodes.some(
      (candidate) => nodeKey(candidate) === targetNodeKey
    )
      ? graph
      : { ...graph, nodes: [...nodes, node] };
    const configurationOverrides = new Map();
    if (configuration !== undefined) {
      configurationOverrides.set(targetNodeKey, configuration);
    }
    outputSchemas = resolveDeclaredOutputSchemas(resolutionGraph, {
      configurationOverrides,
      visited,
    });
  }

  return outputSchemas.get(targetNodeKey)?.[outputIndex] || {};
}

export function inputConnectionsForNode(node, graph, visited = new Set()) {
  if (!node) {
    return [];
  }

  return (graph.connections || [])
    .filter(
      (connection) =>
        connection.targetClientId === node.clientId &&
        connection.sourceClientId !== node.clientId &&
        !visited.has(connection.sourceClientId)
    )
    .sort(connectionOrder);
}

export function previousNodeForConnection(connection, graph) {
  if (!connection) {
    return null;
  }

  return (
    (graph.nodes || []).find(
      (node) => node.clientId === connection.sourceClientId
    ) || null
  );
}

export function ancestorOutputNodes(node, graph) {
  const ancestors = [];
  const visitedNodes = new Set(node ? [node.clientId] : []);
  const seenAncestors = new Set();
  const pendingConnections = inputConnectionsForNode(node, graph);

  while (pendingConnections.length) {
    const connection = pendingConnections.shift();
    const previous = previousNodeForConnection(connection, graph);
    if (!previous) {
      continue;
    }

    const outputIndex = normalizeSourceOutputIndex(connection);
    const key = `${previous.clientId}:${outputIndex}`;
    if (!seenAncestors.has(key)) {
      seenAncestors.add(key);
      ancestors.push({
        node: previous,
        outputIndex,
      });
    }

    if (visitedNodes.has(previous.clientId)) {
      continue;
    }
    visitedNodes.add(previous.clientId);
    pendingConnections.push(
      ...inputConnectionsForNode(previous, graph, visitedNodes)
    );
  }

  return ancestors;
}
