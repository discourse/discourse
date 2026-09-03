import { iconElement } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";
import {
  addColumn,
  addRow,
  deleteColumn,
  deleteRow,
  emptyTrailingColumns,
  emptyTrailingRows,
} from "./commands";
import dragAutoscroll from "./drag-autoscroll";
import { columnTarget, isTable, rowTarget, tableGrid } from "./grid";
import { runCommand, TABLE_MENU_IDENTIFIER } from "./menu";

const APPEND_DRAG_THRESHOLD = 4;
const APPEND_DRAG_MAX = { column: 8, row: 12 };
const APPEND_DRAG_STEP_EM = { column: 5, row: 2 };
const TOUCH_SCROLL_THRESHOLD = 8;

// The commands that grow or shrink each axis, so one gesture can serve both.
const AXES = {
  column: {
    target: columnTarget,
    add: addColumn,
    remove: deleteColumn,
    emptyTrailing: emptyTrailingColumns,
  },
  row: {
    target: rowTarget,
    add: addRow,
    remove: deleteRow,
    emptyTrailing: emptyTrailingRows,
  },
};

export function buildTableNodeView(pluginParams) {
  return class TableNodeView {
    #hovered = null;
    #stopAppendDrag = null;
    #stopTouchScroll = null;

    #clearPointer = () => {
      this.#hovered = null;
      this.#showHandlesFor(null);
    };

    #trackPointer = (event) => {
      if (!this.view.editable) {
        this.#clearPointer();
        return;
      }

      // A reorder owns the handle it started from; re-targeting mid-drag would
      // take it out from under the pointer.
      if (this.inner.classList.contains("is-reordering")) {
        return;
      }

      const cell = event.target.closest?.("th, td");
      if (!cell || !this.contentDOM.contains(cell) || cell === this.#hovered) {
        return;
      }

      this.#hovered = cell;
      this.#showHandlesFor(cell);
    };

    #trackTouchScroll = (startEvent) => {
      if (
        startEvent.pointerType !== "touch" ||
        !startEvent.isPrimary ||
        startEvent.button !== 0 ||
        startEvent.target.closest?.(".composer-table__grip")
      ) {
        return;
      }

      this.#stopTouchScroll?.();

      const { clientX, clientY, pointerId } = startEvent;
      const initialScroll = this.dom.scrollLeft;
      let scrolling = false;

      const stop = () => {
        this.dom.classList.remove("is-panning");
        document.removeEventListener("pointermove", move);
        document.removeEventListener("pointerup", stop);
        document.removeEventListener("pointercancel", stop);
        this.#stopTouchScroll = null;
      };

      const move = (event) => {
        if (event.pointerId !== pointerId) {
          return;
        }

        const horizontal = event.clientX - clientX;
        const vertical = event.clientY - clientY;
        if (
          !scrolling &&
          (Math.abs(horizontal) < TOUCH_SCROLL_THRESHOLD ||
            Math.abs(horizontal) <= Math.abs(vertical))
        ) {
          return;
        }

        scrolling = true;
        event.preventDefault();
        this.dom.classList.add("is-panning");
        this.dom.scrollLeft = initialScroll - horizontal;
      };

      document.addEventListener("pointermove", move);
      document.addEventListener("pointerup", stop);
      document.addEventListener("pointercancel", stop);
      this.#stopTouchScroll = stop;
    };

    constructor(node, view, getPos) {
      this.node = node;
      this.view = view;
      this.getPos = getPos;

      this.dom = document.createElement("div");
      this.dom.className = "md-table composer-table";

      this.inner = document.createElement("div");
      this.inner.className = "composer-table__inner";
      this.dom.appendChild(this.inner);

      this.contentDOM = document.createElement("table");
      this.inner.appendChild(this.contentDOM);

      this.inner.appendChild(
        this.#appendButton("column", "composer.table.add_column")
      );
      this.inner.appendChild(
        this.#appendButton("row", "composer.table.add_row")
      );

      this.dropIndicator = document.createElement("div");
      this.dropIndicator.className = "composer-table__drop-indicator";
      this.inner.appendChild(this.dropIndicator);

      this.appendGhost = document.createElement("div");
      this.appendGhost.className = "composer-table__ghost";
      this.inner.appendChild(this.appendGhost);

      // Only the pointer's own row and column show a handle, so the table stays
      // quiet while it is being typed in. Done in the DOM rather than through a
      // transaction: hovering a cell is not a document change.
      this.dom.addEventListener("mousemove", this.#trackPointer);
      this.dom.addEventListener("mouseleave", this.#clearPointer);
      this.contentDOM.addEventListener("pointerdown", this.#trackTouchScroll);
      this.#syncEditable();
    }

    destroy() {
      this.#stopAppendDrag?.();
      this.#stopTouchScroll?.();
      this.dom.removeEventListener("mousemove", this.#trackPointer);
      this.dom.removeEventListener("mouseleave", this.#clearPointer);
      this.contentDOM.removeEventListener(
        "pointerdown",
        this.#trackTouchScroll
      );
    }

    update(node) {
      if (node.type !== this.node.type) {
        return false;
      }
      this.node = node;
      this.#syncEditable();
      return true;
    }

    stopEvent(event) {
      return !!event.target.closest?.(
        `.composer-table__append, [data-identifier="${TABLE_MENU_IDENTIFIER}"]`
      );
    }

    ignoreMutation(mutation) {
      if (!this.contentDOM.contains(mutation.target)) {
        return true;
      }

      // The chrome puts presentation on the cells themselves while dragging —
      // a lift transform, a state class. Those are not document changes, and
      // letting them count as one makes the editor redraw the table and rebuild
      // every handle mid-gesture.
      return (
        mutation.type === "attributes" &&
        (mutation.attributeName === "style" ||
          mutation.attributeName === "class")
      );
    }

    /**
     * Grows the table by `delta` rows or columns, or drops that many trailing
     * ones when negative. Removal only reaches what the drag has vouched is
     * empty, so the gesture can never destroy anything the author typed.
     */
    #resize(kind, delta) {
      if (!this.view.editable || !delta) {
        return;
      }

      const table = this.#table();
      if (!table) {
        return;
      }

      const axis = AXES[kind];
      const size = kind === "column" ? table.grid.width : table.grid.height;
      const target = axis.target(
        table,
        delta > 0 ? size - 1 : size + delta,
        size - 1
      );

      const changed = runCommand(
        this.view,
        delta > 0 ? axis.add(1, target, delta) : axis.remove(target)
      );
      if (changed) {
        this.#announceChange(kind, delta);
      }
    }

    #appendButton(kind, labelKey) {
      let dragged = false;
      const button = this.#button(`append --${kind}`, labelKey, () => {
        if (dragged) {
          dragged = false;
          return;
        }

        this.#resize(kind, 1);
      });

      button.appendChild(iconElement("plus"));

      const count = document.createElement("span");
      count.className = "composer-table__append-count";
      count.ariaHidden = "true";
      button.appendChild(count);

      button.addEventListener("pointerdown", (event) =>
        this.#trackAppend(event, kind, button, (value) => (dragged = value))
      );
      return button;
    }

    #button(className, labelKey, onClick) {
      const button = document.createElement("button");
      button.type = "button";
      button.className = `composer-table__${className}`;
      button.contentEditable = "false";
      button.tabIndex = -1;
      button.setAttribute("aria-label", i18n(labelKey));
      // Click preserves synthesized activation; mousedown only holds the caret.
      button.addEventListener("mousedown", (event) => event.preventDefault());
      button.addEventListener("click", onClick);
      return button;
    }

    /**
     * Shows what the drag will do: pending rows or columns beyond the edge they
     * will land on, or the empty ones about to be dropped. Adding grows the
     * inner element to match so the scroll box keeps the preview in view.
     */
    #showGhost(kind, delta, step, bounds, rtl = false) {
      const ghost = this.appendGhost;

      ghost.className = "composer-table__ghost";
      ghost.removeAttribute("style");
      this.inner.style.paddingInlineEnd = "";
      this.inner.style.paddingBlockEnd = "";

      if (!delta) {
        return;
      }

      const adding = delta > 0;
      const count = Math.abs(delta);
      const span = adding ? count * step : this.#trailingExtent(kind, count);

      ghost.classList.add(
        "--visible",
        `--${kind}`,
        adding ? "--add" : "--remove"
      );
      ghost.style.setProperty("--ghost-step", `${span / count}px`);

      if (kind === "column") {
        if (adding) {
          this.inner.style.paddingInlineEnd = `${span}px`;
        }
        // Adding draws just past the edge, removing over the doomed columns.
        const offset = adding ? bounds.width : bounds.width - span;
        Object.assign(ghost.style, {
          top: "0px",
          left: `${rtl ? bounds.width - offset - span : offset}px`,
          width: `${span}px`,
          height: `${bounds.height}px`,
        });
      } else {
        if (adding) {
          this.inner.style.paddingBlockEnd = `${span}px`;
        }
        Object.assign(ghost.style, {
          top: `${adding ? bounds.height : bounds.height - span}px`,
          left: "0px",
          width: `${bounds.width}px`,
          height: `${span}px`,
        });
      }
    }

    /** Measured size of the last `count` rows or columns, which vary in size. */
    #trailingExtent(kind, count) {
      const rows = [...this.contentDOM.rows];

      if (kind === "row") {
        return rows
          .slice(-count)
          .reduce(
            (total, row) => total + row.getBoundingClientRect().height,
            0
          );
      }

      return [...(rows[0]?.cells ?? [])]
        .slice(-count)
        .reduce((total, cell) => total + cell.getBoundingClientRect().width, 0);
    }

    #showHandlesFor(cell) {
      for (const grip of this.contentDOM.querySelectorAll(
        ".composer-table__grip"
      )) {
        grip.classList.remove("is-visible");
      }

      if (!cell) {
        return;
      }

      const row = cell.parentElement;
      const column = [...row.cells].indexOf(cell);

      row.cells[0]
        ?.querySelector(".composer-table__grip.--row")
        ?.classList.add("is-visible");
      this.contentDOM.rows[0]?.cells[column]
        ?.querySelector(".composer-table__grip.--column")
        ?.classList.add("is-visible");
    }

    #table() {
      const pos = this.getPos();
      if (pos === undefined) {
        return null;
      }

      const node = this.view.state.doc.nodeAt(pos);
      if (!isTable(node)) {
        return null;
      }

      return { node, pos, start: pos + 1, grid: tableGrid(node) };
    }

    #syncEditable() {
      for (const button of this.inner.querySelectorAll(
        ".composer-table__append"
      )) {
        button.hidden = !this.view.editable;
        button.disabled = !this.view.editable;
      }
    }

    #announceChange(kind, delta) {
      const change = delta > 0 ? "added" : "removed";
      pluginParams
        .getContext()
        .a11y.announce(
          i18n(`composer.table.${kind}s_${change}`, { count: Math.abs(delta) })
        );
    }

    #trackAppend(startEvent, kind, button, setDragged) {
      if (!this.view.editable || startEvent.button !== 0) {
        return;
      }

      startEvent.preventDefault();

      // A drag that ends off the button gets no click, so the suppression flag
      // has to be cleared by the next press rather than by the click it eats.
      setDragged(false);
      this.#stopAppendDrag?.();

      const table = this.#table();
      if (!table) {
        return;
      }

      const column = kind === "column";
      const { pointerId } = startEvent;
      const origin = column ? startEvent.clientX : startEvent.clientY;

      const bounds = this.contentDOM.getBoundingClientRect();
      const style = getComputedStyle(this.contentDOM);
      const measuredStep = column
        ? bounds.width / table.grid.width
        : bounds.height / table.grid.height;
      const fontSize = parseFloat(style.fontSize) || 16;
      const step = Math.max(measuredStep, fontSize * APPEND_DRAG_STEP_EM[kind]);
      const rtl = style.direction === "rtl";
      const direction = column && rtl ? -1 : 1;
      const removable = AXES[kind].emptyTrailing(table.grid);

      const countElement = button.querySelector(
        ".composer-table__append-count"
      );

      let dragging = false;
      let delta = 0;
      let current = origin;
      let scrollDistance = 0;

      const reset = () => {
        button.classList.remove("is-appending", "is-removing");
        countElement.textContent = "";
        this.#showGhost(kind, 0, step, bounds);
      };

      const updateDelta = () => {
        const distance = (current - origin) * direction + scrollDistance;

        if (!dragging && Math.abs(distance) < APPEND_DRAG_THRESHOLD) {
          return false;
        }

        if (!dragging) {
          dragging = true;
          setDragged(true);
        }

        const steps = Math.min(
          Math.round(Math.abs(distance) / Math.max(step, 1)),
          APPEND_DRAG_MAX[kind]
        );
        delta = distance > 0 ? steps : -Math.min(steps, removable);

        if (!delta) {
          reset();
          return true;
        }

        button.classList.toggle("is-appending", delta > 0);
        button.classList.toggle("is-removing", delta < 0);
        countElement.textContent = delta > 0 ? `+${delta}` : `\u2212${-delta}`;
        this.#showGhost(kind, delta, step, bounds, rtl);
        return true;
      };

      const autoscroll = dragAutoscroll(
        button.closest(".composer-table"),
        column ? "X" : "Y",
        (change) => {
          scrollDistance += change * direction;
          updateDelta();
        }
      );

      const move = (event) => {
        if (event.pointerId !== pointerId) {
          return;
        }

        current = column ? event.clientX : event.clientY;
        if (!updateDelta()) {
          return;
        }

        event.preventDefault();
        autoscroll.update(event);
      };

      const finish = (event) => {
        if (event.pointerId !== pointerId) {
          return;
        }

        this.#stopAppendDrag?.();
        reset();

        if (event.type === "pointercancel") {
          setDragged(false);
          return;
        }

        this.#resize(kind, delta);
      };

      this.#stopAppendDrag = () => {
        autoscroll.stop();
        document.removeEventListener("pointermove", move);
        document.removeEventListener("pointerup", finish);
        document.removeEventListener("pointercancel", finish);
        this.#stopAppendDrag = null;
      };

      document.addEventListener("pointermove", move);
      document.addEventListener("pointerup", finish);
      document.addEventListener("pointercancel", finish);
    }
  };
}
