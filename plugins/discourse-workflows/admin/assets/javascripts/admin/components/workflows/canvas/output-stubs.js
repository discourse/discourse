import { buildConnectedOutputsIndex } from "../../../lib/workflows/graph-constants";

const STUB_LENGTH = 30;

function buildStubEntry(nodeEntry, nodeId, outputKey, startPos) {
  const endX = startPos.x + STUB_LENGTH;
  return {
    areaElement: nodeEntry.element.parentElement,
    nodeClientId: nodeId,
    outputKey,
    pathD: `M ${startPos.x} ${startPos.y} L ${endX} ${startPos.y}`,
    buttonX: endX,
    buttonY: startPos.y - 7,
  };
}

export function updateOutputStubs(
  outputStubEntries,
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
  const activeStubKeys = new Set();
  const promises = [];

  for (const [nodeId, nodeEntry] of nodeEntries) {
    const node = nodeEntry.node;

    for (const outputKey of Object.keys(node.outputs)) {
      if (outputKey === "loop") {
        continue;
      }

      const stubKey = `${nodeId}:${outputKey}`;
      const isConnected = connectedOutputs.get(nodeId)?.has(outputKey) ?? false;

      if (isConnected) {
        outputStubEntries.delete(stubKey);
        continue;
      }

      activeStubKeys.add(stubKey);

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
          outputStubEntries.set(
            stubKey,
            buildStubEntry(nodeEntry, nodeId, outputKey, startPos)
          );
        })()
      );
    }
  }

  return Promise.all(promises).then(() => {
    for (const stubKey of outputStubEntries.keys()) {
      if (!activeStubKeys.has(stubKey)) {
        outputStubEntries.delete(stubKey);
      }
    }
  });
}
