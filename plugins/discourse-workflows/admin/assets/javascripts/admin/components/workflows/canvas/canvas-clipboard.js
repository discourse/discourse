import { i18n } from "discourse-i18n";

const PAYLOAD_TYPE = "discourse-workflows/canvas-selection";
const PAYLOAD_VERSION = 1;
const MARKER_NAME = "discourse-workflows-canvas-selection";
const MARKER_PREFIX = `<!-- ${MARKER_NAME}:v${PAYLOAD_VERSION}:`;
const MARKER_PATTERN = new RegExp(
  `<!--\\s*${MARKER_NAME}:v${PAYLOAD_VERSION}:([A-Za-z0-9+/=]+)\\s*-->`
);
const STICKY_NOTE_COLORS = new Set([
  "yellow",
  "blue",
  "green",
  "pink",
  "purple",
  "orange",
]);

function normalizeLineEndings(text) {
  return typeof text === "string" ? text.replace(/\r\n/g, "\n") : text;
}

export function isSerializedCanvasClipboardPayload(text, serializedPayload) {
  return Boolean(
    text &&
    serializedPayload &&
    normalizeLineEndings(text) === normalizeLineEndings(serializedPayload)
  );
}

function clonePosition(position) {
  if (!position || typeof position !== "object") {
    return null;
  }

  const x = Number(position.x);
  const y = Number(position.y);

  if (!Number.isFinite(x) || !Number.isFinite(y)) {
    return null;
  }

  return { x, y };
}

function cloneSize(size) {
  if (!size || typeof size !== "object") {
    return null;
  }

  const width = Number(size.width);
  const height = Number(size.height);

  if (!Number.isFinite(width) || !Number.isFinite(height)) {
    return null;
  }

  return { width, height };
}

function cloneColor(color) {
  return STICKY_NOTE_COLORS.has(color) ? color : undefined;
}

function cloneNodeForClipboard(node) {
  return {
    clientId: node.clientId,
    type: node.type,
    typeVersion: node.typeVersion,
    name: node.name,
    configuration: structuredClone(node.configuration || {}),
    position: clonePosition(node.position),
  };
}

function cloneStickyNoteForClipboard(note) {
  return {
    clientId: note.clientId,
    position: clonePosition(note.position),
    size: cloneSize(note.size),
    color: cloneColor(note.color),
    text: note.text,
  };
}

function cloneConnectionForClipboard(connection) {
  return structuredClone(connection);
}

function encodeBase64(text) {
  const bytes = new TextEncoder().encode(text);
  let binary = "";

  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }

  return btoa(binary);
}

function decodeBase64(text) {
  const binary = atob(text);
  const bytes = Uint8Array.from(binary, (char) => char.charCodeAt(0));

  return new TextDecoder().decode(bytes);
}

function normalizeArray(value) {
  return Array.isArray(value) ? value : [];
}

function validNode(node) {
  return (
    node &&
    typeof node === "object" &&
    !Array.isArray(node) &&
    typeof node.clientId === "string" &&
    typeof node.type === "string"
  );
}

function validStickyNote(note) {
  return (
    note &&
    typeof note === "object" &&
    !Array.isArray(note) &&
    typeof note.clientId === "string"
  );
}

function validConnection(connection) {
  return (
    connection &&
    typeof connection === "object" &&
    !Array.isArray(connection) &&
    typeof connection.sourceClientId === "string" &&
    typeof connection.targetClientId === "string"
  );
}

function uniqueByClientId(items) {
  const seen = new Set();

  return items.filter((item) => {
    if (seen.has(item.clientId)) {
      return false;
    }

    seen.add(item.clientId);
    return true;
  });
}

function normalizeClipboardTarget(target) {
  if (!target) {
    return null;
  }

  const x = target.canvasX ?? target.x;
  const y = target.canvasY ?? target.y;

  if (!Number.isFinite(x) || !Number.isFinite(y)) {
    return null;
  }

  return { x, y };
}

export function buildCanvasClipboardPayload(
  { nodes = [], connections = [], stickyNotes = [] },
  { nodeIds = new Set(), stickyNoteIds = new Set() }
) {
  const selectedNodeIds = new Set(nodeIds);
  const selectedStickyNoteIds = new Set(stickyNoteIds);
  const copiedNodes = nodes
    .filter((node) => selectedNodeIds.has(node.clientId))
    .map(cloneNodeForClipboard);
  const copiedStickyNotes = stickyNotes
    .filter((note) => selectedStickyNoteIds.has(note.clientId))
    .map(cloneStickyNoteForClipboard);

  if (copiedNodes.length === 0 && copiedStickyNotes.length === 0) {
    return null;
  }

  return {
    type: PAYLOAD_TYPE,
    version: PAYLOAD_VERSION,
    nodes: copiedNodes,
    connections: connections
      .filter(
        (connection) =>
          selectedNodeIds.has(connection.sourceClientId) &&
          selectedNodeIds.has(connection.targetClientId)
      )
      .map(cloneConnectionForClipboard),
    stickyNotes: copiedStickyNotes,
  };
}

export function serializeCanvasClipboardPayload(payload) {
  const encodedPayload = encodeBase64(JSON.stringify(payload));

  return `${i18n("discourse_workflows.canvas.clipboard_text")}\n${MARKER_PREFIX}${encodedPayload} -->`;
}

export function parseCanvasClipboardText(text) {
  if (!text || typeof text !== "string") {
    return null;
  }

  const encodedPayload = text.match(MARKER_PATTERN)?.[1];
  let payloadText;
  let payload;

  try {
    payloadText = encodedPayload ? decodeBase64(encodedPayload) : text.trim();
    payload = JSON.parse(payloadText);
  } catch {
    return null;
  }

  return normalizeCanvasClipboardPayload(payload);
}

export function payloadForCanvasClipboardPaste(parsedPayload, localPayload) {
  return parsedPayload || localPayload || null;
}

export function normalizeCanvasClipboardPayload(payload) {
  if (
    !payload ||
    typeof payload !== "object" ||
    Array.isArray(payload) ||
    payload.type !== PAYLOAD_TYPE ||
    payload.version !== PAYLOAD_VERSION
  ) {
    return null;
  }

  const nodes = uniqueByClientId(
    normalizeArray(payload.nodes).filter(validNode)
  );
  const stickyNotes = uniqueByClientId(
    normalizeArray(payload.stickyNotes).filter(validStickyNote)
  );
  const nodeIds = new Set(nodes.map((node) => node.clientId));
  const connections = normalizeArray(payload.connections).filter(
    (connection) =>
      validConnection(connection) &&
      nodeIds.has(connection.sourceClientId) &&
      nodeIds.has(connection.targetClientId)
  );

  if (nodes.length === 0 && stickyNotes.length === 0) {
    return null;
  }

  return {
    type: PAYLOAD_TYPE,
    version: PAYLOAD_VERSION,
    nodes: nodes.map((node) => ({
      clientId: node.clientId,
      type: node.type,
      typeVersion: node.typeVersion,
      name: node.name,
      configuration:
        node.configuration &&
        typeof node.configuration === "object" &&
        !Array.isArray(node.configuration)
          ? structuredClone(node.configuration)
          : {},
      position: clonePosition(node.position),
    })),
    connections: structuredClone(connections),
    stickyNotes: stickyNotes.map((note) => ({
      clientId: note.clientId,
      position: clonePosition(note.position),
      size: cloneSize(note.size),
      color: cloneColor(note.color),
      text: note.text,
    })),
  };
}

export function positionCanvasClipboardPayload(
  payload,
  { target = null, sourceOffset = 0 } = {}
) {
  const nodes = structuredClone(payload.nodes || []);
  const stickyNotes = structuredClone(payload.stickyNotes || []);
  const items = [...nodes, ...stickyNotes];
  const targetPosition = normalizeClipboardTarget(target);
  const positionedItems = items.filter((item) => item.position);

  if (targetPosition) {
    if (positionedItems.length > 0) {
      const xs = positionedItems.map((item) => item.position.x);
      const ys = positionedItems.map((item) => item.position.y);
      const centerX = (Math.min(...xs) + Math.max(...xs)) / 2;
      const centerY = (Math.min(...ys) + Math.max(...ys)) / 2;
      const dx = targetPosition.x - centerX;
      const dy = targetPosition.y - centerY;

      items.forEach((item, index) => {
        item.position = item.position
          ? { x: item.position.x + dx, y: item.position.y + dy }
          : {
              x: targetPosition.x + index * 20,
              y: targetPosition.y + index * 20,
            };
      });
    } else {
      items.forEach((item, index) => {
        item.position = {
          x: targetPosition.x + index * 20,
          y: targetPosition.y + index * 20,
        };
      });
    }
  } else if (sourceOffset) {
    for (const item of items) {
      if (item.position) {
        item.position = {
          x: item.position.x + sourceOffset,
          y: item.position.y + sourceOffset,
        };
      }
    }
  }

  return {
    nodes,
    connections: structuredClone(payload.connections || []),
    stickyNotes,
  };
}
