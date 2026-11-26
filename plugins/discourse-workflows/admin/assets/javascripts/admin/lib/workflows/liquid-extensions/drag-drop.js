import { WORKFLOW_VARIABLE_MIME } from "../expression-context.js";
import { liquidPathForVariable } from "../liquid-context.js";
import { liquidDropContext } from "./drop-context.js";

export function buildLiquidDragDrop(
  { cmLanguage, cmView },
  { perItem, secondaryInputs }
) {
  const { dropCursor, ViewPlugin } = cmView;

  function handleDragOver(event) {
    if (event.dataTransfer.types.includes(WORKFLOW_VARIABLE_MIME)) {
      event.preventDefault();
      event.dataTransfer.dropEffect = "copy";
    }
  }

  function handleDrop(view, event) {
    if (view.state.readOnly) {
      return;
    }
    const data = event.dataTransfer.getData(WORKFLOW_VARIABLE_MIME);
    if (!data) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }

    // Past the last line means append.
    const pos =
      view.posAtCoords({ x: event.clientX, y: event.clientY }) ??
      view.state.doc.length;

    const context = liquidDropContext(view.state, pos, cmLanguage);
    if (!context) {
      return;
    }
    const path = liquidPathForVariable(variable.id, context.loops, {
      perItem: perItem(),
      secondaryInputs: secondaryInputs(),
    });
    if (!path) {
      return;
    }

    const insert = context.expression ? path : `{{ ${path} }}`;

    view.dispatch({
      changes: { from: pos, insert },
      selection: { anchor: pos, head: pos + insert.length },
    });
    view.focus();
  }

  // On the editor root so drops below the last line land; capture runs ahead
  // of the editor's own drop handling.
  const dropListeners = ViewPlugin.fromClass(
    class {
      constructor(view) {
        this.view = view;
        this.onDrop = (event) => handleDrop(view, event);
        view.dom.addEventListener("dragover", handleDragOver, {
          capture: true,
        });
        view.dom.addEventListener("drop", this.onDrop, { capture: true });
      }

      destroy() {
        this.view.dom.removeEventListener("dragover", handleDragOver, {
          capture: true,
        });
        this.view.dom.removeEventListener("drop", this.onDrop, {
          capture: true,
        });
      }
    }
  );

  return [dropCursor(), dropListeners];
}
