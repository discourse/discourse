import { WORKFLOW_VARIABLE_MIME } from "../expression-context";
import {
  itemPrefixAt,
  liquidPathForVariable,
  openDelimiterAt,
} from "../liquid-context";

export function buildLiquidDragDrop({ cmView }, { perItem }) {
  const { dropCursor, ViewPlugin } = cmView;

  function handleDragOver(event) {
    if (event.dataTransfer.types.includes(WORKFLOW_VARIABLE_MIME)) {
      event.preventDefault();
      event.dataTransfer.dropEffect = "copy";
    }
  }

  function handleDrop(view, event) {
    const data = event.dataTransfer.getData(WORKFLOW_VARIABLE_MIME);
    if (!data) {
      return;
    }

    // Ours to place (capture phase), ahead of CodeMirror's own drop handling.
    event.preventDefault();
    event.stopPropagation();

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }

    // Dropped past the last line means append rather than nothing.
    const pos =
      view.posAtCoords({ x: event.clientX, y: event.clientY }) ??
      view.state.doc.length;

    const text = view.state.doc.toString();
    const path = liquidPathForVariable(
      variable.id,
      itemPrefixAt(text, pos, { perItem: perItem() })
    );

    // Nothing sensible to insert for a source the template cannot reach.
    if (!path) {
      return;
    }

    // Inside a delimiter the path stands alone; in plain text it needs its own
    // output tag to render.
    const insert = openDelimiterAt(text, pos) ? path : `{{ ${path} }}`;

    view.dispatch({
      changes: { from: pos, insert },
      selection: { anchor: pos, head: pos + insert.length },
    });
    view.focus();
  }

  // Bound to the editor element rather than contentDOM so drops below the last
  // line register; capture runs ahead of CodeMirror's own handler.
  const dropListeners = ViewPlugin.fromClass(
    class {
      constructor(view) {
        this.view = view;
        this.onDragOver = handleDragOver;
        this.onDrop = (event) => handleDrop(view, event);
        view.dom.addEventListener("dragover", this.onDragOver, {
          capture: true,
        });
        view.dom.addEventListener("drop", this.onDrop, { capture: true });
      }

      destroy() {
        this.view.dom.removeEventListener("dragover", this.onDragOver, {
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
