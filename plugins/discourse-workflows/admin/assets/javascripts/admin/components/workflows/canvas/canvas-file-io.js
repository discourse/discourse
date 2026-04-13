import StickyNote, { STICKY_NOTE_TYPE } from "../../../models/sticky-note";

export function exportWorkflowToFile(nodes, connections, stickyNotes) {
  const exportedNodes = (nodes || []).map((n) => ({
    type: n.type,
    type_version: n.type_version,
    name: n.name,
    configuration: n.configuration || {},
    position: n.position || null,
  }));

  const exportedStickyNotes = (stickyNotes || []).map((n) => ({
    type: STICKY_NOTE_TYPE,
    type_version: "1.0",
    name: "Sticky Note",
    configuration: {
      content: n.text,
      width: n.size.width,
      height: n.size.height,
      color: n.color,
    },
    position: n.position,
  }));

  const allNodes = [...exportedNodes, ...exportedStickyNotes];

  const clientIdToIndex = new Map((nodes || []).map((n, i) => [n.clientId, i]));

  const exportedConnections = (connections || [])
    .filter(
      (c) =>
        clientIdToIndex.has(c.sourceClientId) &&
        clientIdToIndex.has(c.targetClientId)
    )
    .map((c) => ({
      source_index: clientIdToIndex.get(c.sourceClientId),
      target_index: clientIdToIndex.get(c.targetClientId),
      source_output: c.sourceOutput || "main",
    }));

  const payload = {
    version: 1,
    nodes: allNodes,
    connections: exportedConnections,
  };

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

  if (!data || typeof data.version !== "number") {
    return { error: "invalid" };
  }

  if (data.version !== 1) {
    return { error: "version" };
  }

  if (!Array.isArray(data.nodes) || data.nodes.length === 0) {
    return { error: "invalid" };
  }

  const allImportedNodes = data.nodes.map((n) => ({
    clientId: crypto.randomUUID(),
    type: n.type,
    type_version: n.type_version,
    name: n.name,
    configuration: n.configuration || {},
    position: n.position || null,
  }));

  const regularNodes = allImportedNodes.filter(
    (n) => n.type !== STICKY_NOTE_TYPE
  );

  const newStickyNotes = allImportedNodes
    .filter((n) => n.type === STICKY_NOTE_TYPE)
    .map((n) =>
      StickyNote.create({
        position: n.position,
        size: {
          width: n.configuration?.width,
          height: n.configuration?.height,
        },
        color: n.configuration?.color,
        text: n.configuration?.content,
      })
    );

  // Also handle legacy format with separate sticky_notes array
  if (Array.isArray(data.sticky_notes)) {
    data.sticky_notes.forEach((n) => {
      newStickyNotes.push(StickyNote.create(n));
    });
  }

  const newConnections = (data.connections || [])
    .filter(
      (c) =>
        c.source_index >= 0 &&
        c.source_index < regularNodes.length &&
        c.target_index >= 0 &&
        c.target_index < regularNodes.length
    )
    .map((c) => ({
      sourceClientId: regularNodes[c.source_index].clientId,
      targetClientId: regularNodes[c.target_index].clientId,
      sourceOutput: c.source_output || "main",
    }));

  return {
    nodes: regularNodes,
    connections: newConnections,
    stickyNotes: newStickyNotes,
  };
}
