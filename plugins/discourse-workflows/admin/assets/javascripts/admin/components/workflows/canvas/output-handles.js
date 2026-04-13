import { buildConnectedOutputsIndex } from "../../../lib/workflows/graph-constants";

const HANDLE_LENGTH = 30;

function buildHandleEntry(nodeEntry, nodeId, outputKey, startPos) {
  const endX = startPos.x + HANDLE_LENGTH;
  return {
    areaElement: nodeEntry.element.parentElement,
    nodeClientId: nodeId,
    outputKey,
    pathD: `M ${startPos.x} ${startPos.y} L ${endX} ${startPos.y}`,
    buttonX: endX,
    buttonY: startPos.y - 7,
  };
}

export function updateOutputHandles(
  outputHandleEntries,
  nodeEntries,
  connectionElements,
  getSocketCanvasPos,
  dirtyNodeIds
) {
  const connectedOutputs = buildConnectedOutputsIndex(
    [...connectionElements.values()]
      .filter((e) => !e.payload?.isPseudo)
      .map((e) => e.payload)
  );
  const activeHandleKeys = new Set();
  const promises = [];

  for (const [nodeId, nodeEntry] of nodeEntries) {
    const node = nodeEntry.node;

    for (const outputKey of Object.keys(node.outputs)) {
      if (outputKey === "loop") {
        continue;
      }

      const handleKey = `${nodeId}:${outputKey}`;
      const isConnected = connectedOutputs.get(nodeId)?.has(outputKey) ?? false;

      if (isConnected) {
        outputHandleEntries.delete(handleKey);
        continue;
      }

      activeHandleKeys.add(handleKey);

      if (dirtyNodeIds && !dirtyNodeIds.has(nodeId)) {
        continue;
      }

      promises.push(
        (async () => {
          const startPos = await getSocketCanvasPos(
            nodeId,
            "output",
            outputKey
          );
          if (!startPos) {
            return;
          }
          outputHandleEntries.set(
            handleKey,
            buildHandleEntry(nodeEntry, nodeId, outputKey, startPos)
          );
        })()
      );
    }
  }

  return Promise.all(promises).then(() => {
    for (const handleKey of outputHandleEntries.keys()) {
      if (!activeHandleKeys.has(handleKey)) {
        outputHandleEntries.delete(handleKey);
      }
    }
  });
}
