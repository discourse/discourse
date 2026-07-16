import {
  resolveVariableId,
  WORKFLOW_VARIABLE_MIME,
} from "../expression-context";
import { dragSource } from "./drag-source";
import {
  listReferenceProperties,
  propertyAccessor,
} from "./reference-properties";

export function buildDragDrop(
  { cmLanguage, cmView },
  { itemPrefix, scope, onOpenReferencePicker }
) {
  const { ensureSyntaxTree } = cmLanguage;
  const { dropCursor, ViewPlugin } = cmView;

  // An object container isn't a usable value, so open the picker on the pill.
  function dropWithPicker(view, pos, variableId) {
    const insert = `{{ ${variableId} }}`;
    view.dispatch({
      changes: { from: pos, insert },
      selection: { anchor: pos, head: pos + insert.length },
    });
    view.focus();

    const properties = listReferenceProperties(scope, variableId);
    if (!properties.length) {
      return;
    }
    const pill = view.dom.querySelector(".cm-wf-reference-pill.--selected");
    if (!pill) {
      return;
    }
    // Capture the range now; the caret may move while the menu is open.
    const range = { from: pos, to: pos + insert.length };
    onOpenReferencePicker({
      trigger: pill,
      properties,
      onSelect: (name) => {
        const replacement = `{{ ${variableId}${propertyAccessor(name)} }}`;
        view.dispatch({
          changes: { from: range.from, to: range.to, insert: replacement },
          selection: {
            anchor: range.from,
            head: range.from + replacement.length,
          },
        });
        view.focus();
      },
      onEdit: () => {
        view.dispatch({
          selection: { anchor: range.from + 2, head: range.to - 2 },
        });
        view.focus();
      },
    });
  }

  function handleDragOver(event) {
    if (event.dataTransfer.types.includes(WORKFLOW_VARIABLE_MIME)) {
      event.preventDefault();
      // Dragging an existing pill moves it; dragging from the panel copies.
      event.dataTransfer.dropEffect = dragSource.current ? "move" : "copy";
    }
  }

  function handleDrop(view, event) {
    const data = event.dataTransfer.getData(WORKFLOW_VARIABLE_MIME);
    if (!data) {
      return;
    }

    // Handle it ourselves (capture phase) before CodeMirror's own drop logic.
    event.preventDefault();
    event.stopPropagation();

    let variable;
    try {
      variable = JSON.parse(data);
    } catch {
      return;
    }

    const variableId = resolveVariableId(variable, itemPrefix);

    let pos = view.posAtCoords({ x: event.clientX, y: event.clientY });
    if (pos === null) {
      // Dropped in the empty area below the text — append to the end.
      pos = view.state.doc.length;
    }

    let inside = false;
    const tree = ensureSyntaxTree(view.state, view.state.doc.length, 100);
    if (tree) {
      for (const side of [-1, 1]) {
        let n = tree.resolve(pos, side);
        while (n) {
          if (n.name === "Expression") {
            inside = pos > n.from + 2 && pos < n.to - 2;
            break;
          }
          n = n.parent;
        }
        if (inside) {
          break;
        }
      }
    }
    const insert = inside ? variableId : `{{ ${variableId} }}`;

    const source = dragSource.current;
    dragSource.current = null;

    if (source && source.view === view) {
      if (pos >= source.from && pos <= source.to) {
        return;
      }
      // Same field: one transaction over the pre-change document.
      const delLen = source.to - source.from;
      const insertedAt = pos > source.to ? pos - delLen : pos;
      view.dispatch({
        changes: [
          { from: pos, insert },
          { from: source.from, to: source.to },
        ],
        selection: { anchor: insertedAt, head: insertedAt + insert.length },
      });
      view.focus();
      return;
    }

    if (source) {
      // The original lives in a different editor, so remove it there.
      view.dispatch({
        changes: { from: pos, insert },
        selection: { anchor: pos, head: pos + insert.length },
      });
      source.view.dispatch({
        changes: { from: source.from, to: source.to },
      });
      view.focus();
      return;
    }

    if (variable.type === "object" && !inside && onOpenReferencePicker) {
      dropWithPicker(view, pos, variableId);
      return;
    }

    view.dispatch({
      changes: { from: pos, insert },
      selection: { anchor: pos, head: pos + insert.length },
    });
    view.focus();
  }

  // On the editor element, not contentDOM, so drops below the last line land;
  // capture runs before CodeMirror's own handler.
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
