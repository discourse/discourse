import { isStaticDataMap } from "../../../lib/workflows/static-data";
import StickyNote, { STICKY_NOTE_TYPE } from "../../../models/sticky-note";
import {
  deserializeConnections,
  serializeConnections,
} from "../../../models/workflow-connection";
import WorkflowNode, {
  NODE_DIRECT_SETTING_KEYS,
} from "../../../models/workflow-node";

function sanitizeImportedObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  const sanitized = structuredClone(value);
  delete sanitized.credentials;
  return sanitized;
}

function cloneObject(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  return structuredClone(value);
}

function importedStaticData(data) {
  if (!Object.hasOwn(data, "staticData")) {
    return undefined;
  }

  const staticData = data.staticData;
  if (!isStaticDataMap(staticData)) {
    return { error: "invalid" };
  }

  return structuredClone(staticData);
}

function directSettingsFromImportedNode(node) {
  const settings = {};

  for (const key of NODE_DIRECT_SETTING_KEYS) {
    if (Object.hasOwn(node, key)) {
      settings[key] = structuredClone(node[key]);
    }
  }

  return settings;
}

function hasUnsupportedNodeKey(node) {
  if (!node || typeof node !== "object") {
    return false;
  }

  return ["type_version", "webhook_id", "position_index", "settings"].some(
    (key) => Object.hasOwn(node, key)
  );
}

export function buildWorkflowExportPayload(
  nodes,
  connections,
  stickyNotes,
  workflow = {}
) {
  const workflowMetadata = workflow || {};
  const exportedNodes = (nodes || []).map(WorkflowNode.serialize);

  const exportedStickyNotes = (stickyNotes || []).map(StickyNote.serialize);

  const allNodes = [...exportedNodes, ...exportedStickyNotes];

  return {
    id: workflowMetadata.id?.toString() || null,
    name: workflowMetadata.name || null,
    nodes: allNodes,
    connections: serializeConnections(connections || [], [
      ...(nodes || []),
      ...(stickyNotes || []),
    ]),
    settings: cloneObject(workflowMetadata.settings),
    staticData: cloneObject(workflowMetadata.staticData),
    pinData: cloneObject(workflowMetadata.pinData),
    versionId: workflowMetadata.versionId || null,
    activeVersionId: workflowMetadata.activeVersionId || null,
    versionCounter: workflowMetadata.versionCounter || null,
  };
}

export function exportWorkflowToFile(
  nodes,
  connections,
  stickyNotes,
  workflow
) {
  const payload = buildWorkflowExportPayload(
    nodes,
    connections,
    stickyNotes,
    workflow
  );
  const data = JSON.stringify(payload, null, 2);
  const date = new Date().toISOString().slice(0, 10);
  const file = new File([data], `workflow-nodes-${date}.json`, {
    type: "application/json",
  });

  const url = URL.createObjectURL(file);
  const a = document.createElement("a");
  a.href = url;
  a.download = file.name;
  a.click();
  URL.revokeObjectURL(url);
}

export function parseWorkflowImport(text) {
  const data = JSON.parse(text);

  if (!data || typeof data !== "object" || Array.isArray(data)) {
    return { error: "invalid" };
  }

  if (
    data.version ||
    data.sticky_notes ||
    Array.isArray(data.connections) ||
    data.nodes?.some(hasUnsupportedNodeKey)
  ) {
    return { error: "invalid" };
  }

  if (!Array.isArray(data.nodes) || data.nodes.length === 0) {
    return { error: "invalid" };
  }

  const staticData = importedStaticData(data);
  if (staticData?.error) {
    return staticData;
  }

  const allImportedNodes = data.nodes.map((n) =>
    WorkflowNode.create({
      clientId: crypto.randomUUID(),
      type: n.type,
      typeVersion: n.typeVersion,
      name: n.name,
      parameters: sanitizeImportedObject(n.parameters),
      credentials: {},
      webhookId: n.webhookId || null,
      position: n.position || null,
      ...directSettingsFromImportedNode(n),
    })
  );

  const regularNodes = allImportedNodes.filter(
    (n) => n.type !== STICKY_NOTE_TYPE
  );

  const newStickyNotes = allImportedNodes
    .filter((n) => n.type === STICKY_NOTE_TYPE)
    .map((n) =>
      StickyNote.create({
        position: n.position,
        size: {
          width: n.parameters?.width,
          height: n.parameters?.height,
        },
        color: n.parameters?.color,
        text: n.parameters?.content,
      })
    );

  const newConnections = deserializeConnections(data.connections || {}, [
    ...regularNodes,
    ...newStickyNotes,
  ]);

  const result = {
    nodes: regularNodes,
    connections: newConnections,
    stickyNotes: newStickyNotes,
  };

  if (staticData !== undefined) {
    result.staticData = staticData;
  }

  return result;
}
