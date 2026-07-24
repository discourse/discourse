import { trackedMap } from "@ember/reactive/collections";
import {
  buildWorkflowGraphIndex,
  getConnectionKind,
  normalizeSourceOutput,
} from "../../../lib/workflows/graph-constants";
import { updateInputHandles, updateOutputHandles } from "./handles";
import { loopBackLayout, loopBodyPath } from "./rete-path-utils";

function resolveCurve(classicPath, kind) {
  if (kind === "loopBody") {
    return (start, end) => loopBodyPath(start, end, "right");
  }
  if (kind === "loopReturn") {
    return (start, end) => loopBodyPath(start, end, "left");
  }
  return (start, end) => classicPath([start, end], 0.4);
}

export function createCustomRenderer(Scope, getElementCenter, classicPath) {
  return class CustomRenderer extends Scope {
    nodeEntries = trackedMap();

    connectionEntries = trackedMap();

    outputHandleEntries = trackedMap();

    inputHandleEntries = trackedMap();

    onSocketRendered = (nodeId, side, key, socketOrOutputs, element) => {
      const socket =
        side === "input" ? socketOrOutputs : socketOrOutputs[key]?.socket;

      if (!socket) {
        return;
      }

      this.#updateSocketPulseState(element, { side, key });

      this.parentScope().emit({
        type: "render",
        data: { element, type: "socket", nodeId, side, key, socket },
      });
    };

    constructor() {
      super("workflow-renderer");
      this.connectionElements = new Map();
      this.connectionUpdateFrame = null;
      this.graphIndex = buildWorkflowGraphIndex([], []);
      this.hasSeenRealConnection = false;

      this.measureSvg = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "svg"
      );
      this.measurePath = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "path"
      );
      this.measureSvg.appendChild(this.measurePath);
      this.measureSvg.style.cssText =
        "position:absolute;width:0;height:0;overflow:hidden;pointer-events:none";
      document.body.appendChild(this.measureSvg);

      this.addPipe(async (context) => {
        switch (context.type) {
          case "render":
            return await this.#handleRender(context);
          case "unmount": {
            const { element } = context.data;
            for (const [id, entry] of this.nodeEntries) {
              if (entry.element === element) {
                this.nodeEntries.delete(id);
                for (const handleKey of this.outputHandleEntries.keys()) {
                  if (handleKey.startsWith(id + ":")) {
                    this.outputHandleEntries.delete(handleKey);
                  }
                }
                this.inputHandleEntries.delete(id);
                break;
              }
            }
            for (const [id, entry] of this.connectionElements) {
              if (entry.element === element) {
                this.connectionElements.delete(id);
                this.connectionEntries.delete(id);
                break;
              }
            }
            break;
          }
          case "nodetranslated":
            this.scheduleConnectionUpdate(context.data.id);
            break;
        }

        return context;
      });
    }

    get nodeEntryList() {
      return [...this.nodeEntries.values()];
    }

    get connectionEntryList() {
      return [...this.connectionEntries.values()];
    }

    get outputHandleEntryList() {
      return [...this.outputHandleEntries.values()];
    }

    get inputHandleEntryList() {
      return [...this.inputHandleEntries.values()];
    }

    async #handleRender(context) {
      if (context.data.filled) {
        return context;
      }

      const { data } = context;
      switch (data.type) {
        case "node":
          data.element.classList.add("workflow-rete-node-view");
          this.nodeEntries.set(data.payload.id, {
            element: data.element,
            node: data.payload,
          });
          break;
        case "connection":
          data.element.style.zIndex = "0";
          await this.renderConnection(data);
          break;
        case "socket":
          break;
        default:
          return context;
      }

      return { ...context, data: { ...data, filled: true } };
    }

    scheduleConnectionUpdate(nodeId) {
      if (nodeId) {
        this.dirtyNodeIds ??= new Set();
        this.dirtyNodeIds.add(nodeId);
      } else {
        this.dirtyNodeIds = null;
      }

      if (!this.connectionUpdateFrame) {
        this.connectionUpdateFrame = requestAnimationFrame(async () => {
          this.connectionUpdateFrame = null;
          const dirtyNodes = this.dirtyNodeIds;
          this.dirtyNodeIds = null;
          await this.updateConnections(dirtyNodes);
        });
      }
    }

    cancelScheduledConnectionUpdate() {
      if (this.connectionUpdateFrame) {
        cancelAnimationFrame(this.connectionUpdateFrame);
        this.connectionUpdateFrame = null;
      }
    }

    #ensureConnectionElement(id) {
      let entry = this.connectionElements.get(id);
      if (!entry) {
        entry = {};
        this.connectionElements.set(id, entry);
      }
      return entry;
    }

    #createConnectionEntry(element, payload, isPseudo, isLoopBack) {
      return {
        element,
        isPseudo,
        isLoopBack,
        loopNodeClientId: isLoopBack ? payload.source : null,
        connectionInfo:
          isPseudo || isLoopBack
            ? null
            : {
                sourceClientId: payload.source,
                targetClientId: payload.target,
                sourceOutput: payload.sourceOutput,
                sourceOutputIndex: payload.sourceOutputIndex,
                targetInput: payload.targetInput,
                targetInputIndex: payload.targetInputIndex,
              },
        pathD: "",
        arrowTransform: "",
        toolbarX: 0,
        toolbarY: 0,
        loopArrowPoints: "",
        loopButtonX: 0,
        loopButtonY: 0,
      };
    }

    async renderConnection(data) {
      const { element, payload } = data;
      const isPseudo = payload.isPseudo;
      const isLoopBack =
        !isPseudo &&
        payload.source === payload.target &&
        payload.sourceOutput === "loop";

      if (!this.connectionEntries.has(payload.id)) {
        this.connectionEntries.set(
          payload.id,
          this.#createConnectionEntry(element, payload, isPseudo, isLoopBack)
        );
      }

      const entry = this.#ensureConnectionElement(payload.id);
      entry.element = element;
      entry.payload = payload;
      entry.isLoopBack = isLoopBack;

      if (isLoopBack) {
        await this.#updateLoopBackEntry(payload);
      } else {
        const d = await this.computeConnectionPath(payload, {
          explicitStart: data.start,
          explicitEnd: data.end,
        });
        if (d) {
          this.#applyPathToEntry(payload.id, d);
        }
      }
    }

    computeArrowLayout(pathD) {
      this.measurePath.setAttribute("d", pathD);
      const len = this.measurePath.getTotalLength();

      const socketRadius = 9;
      const arrowLen = 10;
      const tip = this.measurePath.getPointAtLength(len - socketRadius);
      const base = this.measurePath.getPointAtLength(
        len - socketRadius - arrowLen
      );
      const angle =
        Math.atan2(tip.y - base.y, tip.x - base.x) * (180 / Math.PI);

      const mid = this.measurePath.getPointAtLength(len / 2);

      return {
        arrowTransform: `translate(${tip.x}, ${tip.y}) rotate(${angle})`,
        toolbarX: mid.x - 24,
        toolbarY: mid.y - 11,
      };
    }

    destroyMeasureSvg() {
      this.measureSvg?.remove();
    }

    #updateConnectionEntry(id, updates) {
      const tracked = this.connectionEntries.get(id);
      if (tracked) {
        this.connectionEntries.set(id, { ...tracked, ...updates });
      }
    }

    #applyPathToEntry(connectionId, pathD) {
      this.#updateConnectionEntry(connectionId, {
        pathD,
        ...this.computeArrowLayout(pathD),
      });
    }

    #hasRealConnections() {
      return [...this.connectionElements.values()].some(
        (entry) => entry.payload && !entry.payload.isPseudo
      );
    }

    #shouldPulseSockets() {
      const hasRealConnections = this.#hasRealConnections();
      this.hasSeenRealConnection ||= hasRealConnections;
      return !hasRealConnections && !this.hasSeenRealConnection;
    }

    #updateSocketPulseState(socketElement, { side, key } = {}) {
      const isConnectableSocket = side !== "output" || key !== "loop";
      socketElement.classList.toggle(
        "is-connectable-hint",
        isConnectableSocket && this.#shouldPulseSockets()
      );
    }

    #updateAllSocketPulseStates() {
      const shouldPulse = this.#shouldPulseSockets();

      for (const { element } of this.nodeEntries.values()) {
        for (const socketElement of element.querySelectorAll(
          ".workflow-rete-node__socket"
        )) {
          socketElement.classList.toggle(
            "is-connectable-hint",
            shouldPulse && !socketElement.classList.contains("--loop")
          );
        }
      }
    }

    async #updateLoopBackEntry(payload) {
      const [startPos, endPos] = await Promise.all([
        this.getSocketCanvasPos(payload.source, "output", "loop"),
        this.getSocketCanvasPos(payload.source, "input", "main"),
      ]);

      if (!startPos || !endPos) {
        return;
      }

      const layout = loopBackLayout(startPos, endPos);
      this.#updateConnectionEntry(payload.id, {
        pathD: layout.d,
        loopArrowPoints: layout.arrowPoints,
        loopButtonX: layout.buttonPosition.x,
        loopButtonY: layout.buttonPosition.y,
      });
    }

    async computeConnectionPath(payload, { explicitStart, explicitEnd } = {}) {
      if (explicitStart || explicitEnd) {
        const [startPos, endPos] = await Promise.all([
          explicitStart ??
            this.getSocketCanvasPos(
              payload.source,
              "output",
              normalizeSourceOutput(payload.sourceOutput)
            ),
          explicitEnd ??
            this.getSocketCanvasPos(
              payload.target,
              "input",
              payload.targetInput || "main"
            ),
        ]);
        return startPos && endPos ? classicPath([startPos, endPos], 0.4) : null;
      }

      const { startPos, endPos, kind } =
        await this.getConnectionEndpoints(payload);
      if (!startPos || !endPos) {
        return null;
      }
      return resolveCurve(classicPath, kind)(startPos, endPos);
    }

    async getConnectionEndpoints(payload) {
      const kind = getConnectionKind(this.graphIndex, payload);
      const srcOutput = normalizeSourceOutput(payload.sourceOutput);
      const isLoopSrc = kind === "loopChain" || kind === "loopReturn";
      const isLoopTgt = kind === "loopBody" || kind === "loopChain";
      const tgtKey =
        kind === "loopBody"
          ? "main"
          : isLoopTgt
            ? srcOutput
            : payload.targetInput || "main";

      const [startPos, endPos] = await Promise.all([
        this.getSocketCanvasPos(
          payload.source,
          isLoopSrc ? "input" : "output",
          isLoopSrc ? "main" : srcOutput
        ),
        this.getSocketCanvasPos(
          payload.target,
          isLoopTgt ? "output" : "input",
          tgtKey
        ),
      ]);

      return { startPos, endPos, kind };
    }

    async getSocketCanvasPos(nodeId, side, key) {
      const area = this.parentScope();
      const nodeView = area.nodeViews.get(nodeId);
      if (!nodeView) {
        return null;
      }

      const nodeEl = nodeView.element.querySelector(".workflow-rete-node");
      if (!nodeEl) {
        return null;
      }

      const selector =
        side === "input"
          ? `.workflow-rete-node__socket.--input[data-socket-key="${CSS.escape(key)}"]`
          : `.workflow-rete-node__socket.--output[data-socket-key="${CSS.escape(key)}"]`;
      const socketEl = nodeEl.querySelector(selector);
      if (!socketEl) {
        return null;
      }

      const pos = nodeView.position;
      const center = await getElementCenter(socketEl, nodeView.element);

      let finalX = pos.x + center.x;
      if (side === "output" && key !== "loop") {
        const pill = socketEl.parentElement?.querySelector(
          ".workflow-rete-node__port-pill"
        );
        if (pill) {
          finalX += pill.offsetWidth + 12;
        }
      }

      return { x: finalX, y: pos.y + center.y };
    }

    async updateConnections(dirtyNodeIds) {
      for (const [, entry] of this.connectionElements) {
        if (entry.payload.isPseudo) {
          continue;
        }

        if (
          dirtyNodeIds &&
          !dirtyNodeIds.has(entry.payload.source) &&
          !dirtyNodeIds.has(entry.payload.target)
        ) {
          continue;
        }

        if (entry.isLoopBack) {
          await this.#updateLoopBackEntry(entry.payload);
          continue;
        }

        const d = await this.computeConnectionPath(entry.payload);
        if (d) {
          this.#applyPathToEntry(entry.payload.id, d);
        }
      }

      await updateOutputHandles(
        this.outputHandleEntries,
        this.nodeEntries,
        this.connectionElements,
        (nodeId, side, key) => this.getSocketCanvasPos(nodeId, side, key),
        dirtyNodeIds
      );

      await updateInputHandles(
        this.inputHandleEntries,
        this.nodeEntries,
        this.connectionElements,
        (nodeId, side, key) => this.getSocketCanvasPos(nodeId, side, key),
        dirtyNodeIds,
        this.graphIndex,
        this.parentScope().area.content.holder
      );

      this.#updateAllSocketPulseStates();
    }
  };
}
