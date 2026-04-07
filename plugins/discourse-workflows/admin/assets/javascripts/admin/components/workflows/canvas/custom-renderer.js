import { trackedMap } from "@ember/reactive/collections";
import {
  buildWorkflowGraphIndex,
  getConnectionKind,
  normalizeSourceOutput,
} from "../../../lib/workflows/graph-constants";
import { updateOutputStubs } from "./output-stubs";
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

    outputStubEntries = trackedMap();

    onSocketRendered = (nodeId, side, key, socketOrOutputs, element) => {
      const socket =
        side === "input" ? socketOrOutputs : socketOrOutputs[key]?.socket;

      if (!socket) {
        return;
      }

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

      this._measureSvg = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "svg"
      );
      this._measurePath = document.createElementNS(
        "http://www.w3.org/2000/svg",
        "path"
      );
      this._measureSvg.appendChild(this._measurePath);
      this._measureSvg.style.cssText =
        "position:absolute;width:0;height:0;overflow:hidden;pointer-events:none";
      document.body.appendChild(this._measureSvg);

      this.addPipe(async (context) => {
        switch (context.type) {
          case "render":
            return await this.#handleRender(context);
          case "unmount": {
            const { element } = context.data;
            for (const [id, entry] of this.nodeEntries) {
              if (entry.element === element) {
                this.nodeEntries.delete(id);
                for (const stubKey of this.outputStubEntries.keys()) {
                  if (stubKey.startsWith(id + ":")) {
                    this.outputStubEntries.delete(stubKey);
                  }
                }
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

    get outputStubEntryList() {
      return [...this.outputStubEntries.values()];
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
        this._dirtyNodeIds ??= new Set();
        this._dirtyNodeIds.add(nodeId);
      } else {
        this._dirtyNodeIds = null;
      }

      if (!this.connectionUpdateFrame) {
        this.connectionUpdateFrame = requestAnimationFrame(async () => {
          this.connectionUpdateFrame = null;
          const dirtyNodes = this._dirtyNodeIds;
          this._dirtyNodeIds = null;
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
      this._measurePath.setAttribute("d", pathD);
      const len = this._measurePath.getTotalLength();

      const t = 0.85;
      const pos = this._measurePath.getPointAtLength(len * t);
      const near = this._measurePath.getPointAtLength(len * t + 1);
      const angle =
        Math.atan2(near.y - pos.y, near.x - pos.x) * (180 / Math.PI);

      const mid = this._measurePath.getPointAtLength(len / 2);

      return {
        arrowTransform: `translate(${pos.x}, ${pos.y}) rotate(${angle})`,
        toolbarX: mid.x - 24,
        toolbarY: mid.y - 11,
      };
    }

    destroyMeasureSvg() {
      this._measureSvg?.remove();
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

    async #updateLoopBackEntry(payload) {
      const [startPos, endPos] = await Promise.all([
        this.getSocketCanvasPos(payload.source, "output", "loop"),
        this.getSocketCanvasPos(payload.source, "input", "input"),
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
            this.getSocketCanvasPos(payload.target, "input", "input"),
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
        kind === "loopBody" ? "main" : isLoopTgt ? srcOutput : "input";

      const [startPos, endPos] = await Promise.all([
        this.getSocketCanvasPos(
          payload.source,
          isLoopSrc ? "input" : "output",
          isLoopSrc ? "input" : srcOutput
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
          ? ".workflow-rete-node__socket.--input"
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

      await updateOutputStubs(
        this.outputStubEntries,
        this.nodeEntries,
        this.connectionElements,
        (nodeId, side, key) => this.getSocketCanvasPos(nodeId, side, key),
        dirtyNodeIds
      );
    }
  };
}
