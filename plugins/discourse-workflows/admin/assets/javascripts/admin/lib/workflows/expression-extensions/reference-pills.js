import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import { walkScope, WORKFLOW_VARIABLE_MIME } from "../expression-context";
import { dragSource } from "./drag-source";
import { parseReference, referenceLabel } from "./reference-label";
import { propertyAccessor, referencePickerData } from "./reference-properties";

// Delay before a selected pill's second click opens the dropdown, so a
// double-click (which edits) isn't misread as two single clicks.
const PILL_OPEN_DELAY = 250;

function referenceState(scope, inner) {
  const resolved = walkScope(scope, inner);
  if (resolved === undefined) {
    return "invalid";
  }
  if (
    resolved !== null &&
    typeof resolved === "object" &&
    !Array.isArray(resolved)
  ) {
    return "incomplete";
  }
  return "value";
}

// Display layer only: the document still holds the real expression.
export function buildReferencePills(
  { cmView, cmLanguage, cmState },
  { scope, onOpenReferencePicker } = {}
) {
  const { Decoration, EditorView, ViewPlugin, WidgetType, keymap } = cmView;
  const { syntaxTree } = cmLanguage;
  const { Prec } = cmState;

  function openDropdown(view, range, anchor) {
    if (!onOpenReferencePicker || !anchor) {
      return false;
    }
    const inner = view.state.doc
      .sliceString(range.from + 2, range.to - 2)
      .trim();
    const data = referencePickerData(scope, inner);
    onOpenReferencePicker({
      trigger: anchor,
      properties: data?.properties || [],
      current: data?.current ?? null,
      onSelect: data
        ? (name) => applyPickedProperty(view, range, data.baseExpr, name)
        : null,
      onEdit: () => enterEditMode(view, range),
    });
    return true;
  }

  // Anchor to the pill, not the caret, for left-edge alignment.
  function selectedPillAnchor(view) {
    return view.dom.querySelector(".cm-wf-reference-pill.--selected");
  }

  function applyPickedProperty(view, range, baseExpr, name) {
    const inner = `${baseExpr}${propertyAccessor(name)}`;
    const replacement = `{{ ${inner} }}`;
    view.dispatch({
      changes: { from: range.from, to: range.to, insert: replacement },
      selection: { anchor: range.from, head: range.from + replacement.length },
    });
    view.focus();

    if (referenceState(scope, inner) === "incomplete") {
      const newRange = {
        from: range.from,
        to: range.from + replacement.length,
      };
      // Next frame, so the just-closed menu settles before reopening.
      requestAnimationFrame(() =>
        openDropdown(view, newRange, selectedPillAnchor(view))
      );
    }
  }

  function expressionRangeAt(view, pos) {
    const tree = syntaxTree(view.state);
    for (const side of [1, -1]) {
      let node = tree.resolve(pos, side);
      while (node) {
        if (node.name === "Expression") {
          return { from: node.from, to: node.to };
        }
        node = node.parent;
      }
    }
    return null;
  }

  function pillRangeAt(view, pos, dir) {
    const tree = syntaxTree(view.state);
    let node = tree.resolve(pos, dir);
    while (node && node.name !== "Expression") {
      node = node.parent;
    }
    if (!node || (dir === 1 ? node.from !== pos : node.to !== pos)) {
      return null;
    }
    const doc = view.state.doc;
    if (doc.lineAt(node.from).number !== doc.lineAt(node.to).number) {
      return null;
    }
    const inner = doc.sliceString(node.from + 2, node.to - 2).trim();
    if (!referenceLabel(parseReference(inner))) {
      return null;
    }
    return { from: node.from, to: node.to };
  }

  function rangeIsSelected(selection, range) {
    return selection.from === range.from && selection.to === range.to;
  }

  function editingPillRange(view) {
    const selection = view.state.selection.main;
    const range = expressionRangeAt(view, selection.head);
    if (
      !range ||
      rangeIsSelected(selection, range) ||
      selection.from < range.from ||
      selection.to > range.to
    ) {
      return null;
    }
    const inner = view.state.doc
      .sliceString(range.from + 2, range.to - 2)
      .trim();
    return referenceLabel(parseReference(inner)) ? range : null;
  }

  function enterEditMode(view, range) {
    view.dispatch({
      selection: { anchor: range.from + 2, head: range.to - 2 },
    });
    view.focus();
  }

  class ReferencePillWidget extends WidgetType {
    constructor(label, raw, inner, selected, state) {
      super();
      this.label = label;
      this.raw = raw;
      this.inner = inner;
      this.selected = selected;
      this.state = state;
    }

    eq(other) {
      return (
        other.raw === this.raw &&
        other.selected === this.selected &&
        other.state === this.state
      );
    }

    destroy() {
      clearTimeout(this.openTimer);
    }

    toDOM(view) {
      const pill = document.createElement("span");
      pill.className = `cm-wf-reference-pill --source-${this.label.sourceType} --${this.state}${
        this.selected ? " --selected" : ""
      }`;
      pill.title = this.raw;

      // "click" not "mousedown", so preventDefault doesn't cancel a drag.
      // First click selects; second opens the dropdown on a timer, so a
      // double-click (edit) isn't misread as two selects.
      pill.addEventListener("click", (event) => {
        event.preventDefault();
        const range = expressionRangeAt(view, view.posAtDOM(pill));
        if (!range) {
          return;
        }
        if (rangeIsSelected(view.state.selection.main, range)) {
          clearTimeout(this.openTimer);
          this.openTimer = setTimeout(
            () => openDropdown(view, range, pill),
            PILL_OPEN_DELAY
          );
        } else {
          view.dispatch({ selection: { anchor: range.from, head: range.to } });
          view.focus();
        }
      });

      pill.addEventListener("dblclick", (event) => {
        event.preventDefault();
        clearTimeout(this.openTimer);
        const range = expressionRangeAt(view, view.posAtDOM(pill));
        if (range) {
          enterEditMode(view, range);
        }
      });

      // Record the source range so the drop handler moves rather than copies.
      pill.draggable = true;
      pill.addEventListener("dragstart", (event) => {
        event.stopPropagation();
        event.dataTransfer.setData(
          WORKFLOW_VARIABLE_MIME,
          JSON.stringify({ id: this.inner })
        );
        event.dataTransfer.effectAllowed = "copyMove";
        const range = expressionRangeAt(view, view.posAtDOM(pill));
        dragSource.current = range
          ? { view, from: range.from, to: range.to }
          : null;
        document.documentElement.dataset.draggingVariable = "true";
      });
      pill.addEventListener("dragend", () => {
        dragSource.current = null;
        delete document.documentElement.dataset.draggingVariable;
      });

      if (this.label.icon) {
        const icon = document.createElement("span");
        icon.className = "cm-wf-reference-pill__icon";
        icon.innerHTML = iconHTML(this.label.icon);
        pill.appendChild(icon);
      }

      const badge = document.createElement("span");
      badge.className = "cm-wf-reference-pill__badge";
      badge.textContent = this.label.badge;
      pill.appendChild(badge);

      if (this.label.path) {
        const path = document.createElement("span");
        path.className = "cm-wf-reference-pill__path";
        path.textContent = this.label.path;
        pill.appendChild(path);
      }

      if (onOpenReferencePicker) {
        const drill = document.createElement("button");
        drill.type = "button";
        drill.className = "cm-wf-reference-pill__drill";
        drill.title = i18n("discourse_workflows.reference_pill.pick_property");
        drill.innerHTML = iconHTML("angle-down");
        drill.addEventListener("mousedown", (event) => {
          // mousedown, not click — click lets the editor collapse the menu first.
          event.preventDefault();
          event.stopPropagation();
          const range = expressionRangeAt(view, view.posAtDOM(pill));
          if (range) {
            openDropdown(view, range, pill);
          }
        });
        drill.addEventListener("click", (event) => event.stopPropagation());
        pill.appendChild(drill);
      }

      return pill;
    }
  }

  function buildDecorations(view) {
    const ranges = [];
    const selection = view.state.selection.main;
    const tree = syntaxTree(view.state);

    for (const { from, to } of view.visibleRanges) {
      tree.iterate({
        from,
        to,
        enter(node) {
          if (node.name !== "Expression") {
            return undefined;
          }

          const range = { from: node.from, to: node.to };
          const selected = rangeIsSelected(selection, range);

          // Caret inside the braces means the user is editing — show raw text.
          if (
            !selected &&
            selection.from < node.to &&
            selection.to > node.from
          ) {
            return false;
          }

          // A replacing decoration can't span a line break.
          if (
            view.state.doc.lineAt(node.from).number !==
            view.state.doc.lineAt(node.to).number
          ) {
            return false;
          }

          const inner = view.state.doc
            .sliceString(node.from + 2, node.to - 2)
            .trim();
          const label = referenceLabel(parseReference(inner));
          if (!label) {
            return false;
          }

          const raw = view.state.doc.sliceString(node.from, node.to);
          const state = referenceState(scope, inner);
          ranges.push(
            Decoration.replace({
              widget: new ReferencePillWidget(
                label,
                raw,
                inner,
                selected,
                state
              ),
            }).range(node.from, node.to)
          );
          return false;
        },
      });
    }

    return Decoration.set(ranges, true);
  }

  const pillPlugin = ViewPlugin.fromClass(
    class {
      constructor(view) {
        this.view = view;
        this.decorations = buildDecorations(view);

        // DModal and CodeMirror grab Escape on capture, so pill-edit cancel must too.
        this.handleEscape = (event) => {
          if (
            event.key !== "Escape" ||
            !view.contentDOM.contains(event.target)
          ) {
            return;
          }
          const range = editingPillRange(view);
          if (!range) {
            return;
          }
          event.stopPropagation();
          event.preventDefault();
          view.dispatch({ selection: { anchor: range.from, head: range.to } });
          view.focus();
        };
        window.addEventListener("keydown", this.handleEscape, {
          capture: true,
        });
      }

      update(update) {
        if (
          update.docChanged ||
          update.viewportChanged ||
          update.selectionSet
        ) {
          this.decorations = buildDecorations(update.view);
        }
      }

      destroy() {
        window.removeEventListener("keydown", this.handleEscape, {
          capture: true,
        });
      }
    },
    {
      decorations: (plugin) => plugin.decorations,
      provide: (plugin) =>
        EditorView.atomicRanges.of(
          (view) => view.plugin(plugin)?.decorations || Decoration.none
        ),
    }
  );

  // Beat the default Enter/arrow bindings when a pill is involved.
  const pillKeymap = Prec.high(
    keymap.of([
      {
        key: "Enter",
        run(view) {
          const selection = view.state.selection.main;
          if (selection.empty) {
            return false;
          }
          const range = expressionRangeAt(view, selection.from);
          if (range && rangeIsSelected(selection, range)) {
            return openDropdown(view, range, selectedPillAnchor(view));
          }
          return false;
        },
      },
      {
        // Select the adjacent pill; a second press moves past it.
        key: "ArrowRight",
        run(view) {
          const selection = view.state.selection.main;
          if (selection.empty) {
            const range = pillRangeAt(view, selection.head, 1);
            if (range) {
              view.dispatch({
                selection: { anchor: range.from, head: range.to },
              });
              return true;
            }
            return false;
          }
          const range = pillRangeAt(view, selection.from, 1);
          if (range && rangeIsSelected(selection, range)) {
            view.dispatch({ selection: { anchor: range.to } });
            return true;
          }
          return false;
        },
      },
      {
        key: "ArrowLeft",
        run(view) {
          const selection = view.state.selection.main;
          if (selection.empty) {
            const range = pillRangeAt(view, selection.head, -1);
            if (range) {
              view.dispatch({
                selection: { anchor: range.from, head: range.to },
              });
              return true;
            }
            return false;
          }
          const range = pillRangeAt(view, selection.from, 1);
          if (range && rangeIsSelected(selection, range)) {
            view.dispatch({ selection: { anchor: range.from } });
            return true;
          }
          return false;
        },
      },
    ])
  );

  // Input handler, not keymap: "." arrives through the input path, not keydown.
  const pillInputHandler = EditorView.inputHandler.of(
    (view, from, to, text) => {
      if (text !== ".") {
        return false;
      }
      const range = expressionRangeAt(view, from);
      if (!range || from !== range.from || to !== range.to) {
        return false;
      }
      return openDropdown(view, range, selectedPillAnchor(view));
    }
  );

  return [pillPlugin, pillKeymap, pillInputHandler];
}
