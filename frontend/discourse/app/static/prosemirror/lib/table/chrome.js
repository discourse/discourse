import { Plugin, PluginKey } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";
import { i18n } from "discourse-i18n";
import { moveColumn, moveRow } from "./commands";
import dragAutoscroll from "./drag-autoscroll";
import {
  cellAround,
  cellCoords,
  findTable,
  isTable,
  rectFor,
  tableGrid,
} from "./grid";
import { handleContextMenuKey, openGripMenu } from "./menu";

const DRAG_THRESHOLD = 4;
const TOUCH_DRAG_THRESHOLD = 12;
const TABLE_CHROME_KEY = new PluginKey("tableChrome");

/**
 * The grips that sit above each column and beside each row.
 *
 * They are widget decorations inside the cells they belong to, so they track
 * cell geometry through CSS alone and never need measuring. Each grip resolves
 * its own row and column from its current position, which keeps them correct
 * after the grid is edited without rebuilding their DOM.
 */
export function tableChrome(pluginParams) {
  const cache = new WeakMap();
  const activeGestures = new Set();

  return new Plugin({
    key: TABLE_CHROME_KEY,

    state: {
      init: () => null,
      apply(tr, target) {
        const next = tr.getMeta(TABLE_CHROME_KEY);
        if (next !== undefined) {
          return next;
        }
        return tr.selectionSet || tr.docChanged ? null : target;
      },
    },

    props: {
      decorations: (state) =>
        chromeDecorations(
          state,
          pluginParams,
          cache,
          activeGestures,
          TABLE_CHROME_KEY.getState(state)
        ),
      handleKeyDown: (view, event) =>
        handleContextMenuKey(view, event, pluginParams),
    },
    view: (view) => {
      syncGripAccessibility(view);

      return {
        update: () => syncGripAccessibility(view),
        destroy: () => {
          [...activeGestures].forEach((stop) => stop());
        },
      };
    },
  });
}

function chromeDecorations(state, pluginParams, cache, activeGestures, target) {
  let set = cache.get(state.doc);
  if (!set) {
    set = gripDecorations(state, pluginParams, activeGestures);
    cache.set(state.doc, set);
  }

  const selected = targetDecorations(state, target);
  return selected.length ? set.add(state.doc, selected) : set;
}

function gripDecorations(state, pluginParams, activeGestures) {
  const decorations = [];

  state.doc.descendants((node, pos) => {
    if (!node.isBlock) {
      return false;
    }
    if (!isTable(node)) {
      return;
    }

    const grid = tableGrid(node);
    const start = pos + 1;

    grid.rows.forEach((row, index) => {
      if (row.cells[0]) {
        decorations.push(
          gripDecoration(
            start + row.cells[0].offset + 1,
            "row",
            pluginParams,
            activeGestures,
            { header: row.header }
          )
        );
      }

      if (index === 0) {
        row.cells.forEach((cell) => {
          decorations.push(
            gripDecoration(
              start + cell.offset + 1,
              "column",
              pluginParams,
              activeGestures
            )
          );
        });
      }
    });

    return false;
  });

  return DecorationSet.create(state.doc, decorations);
}

function targetDecorations(state, target) {
  if (!target) {
    return [];
  }

  const node = state.doc.nodeAt(target.tablePos);
  if (!isTable(node)) {
    return [];
  }

  const grid = tableGrid(node);
  const rect = rectFor(grid, target.kind, target.index);
  const decorations = [];

  // The band is one row or one column, so only its two ends along the axis it
  // runs down need marking; its long sides follow from the axis class.
  const alongRow = target.kind === "row";
  const first = alongRow ? rect.left : rect.top;
  const last = alongRow ? rect.right : rect.bottom;

  for (let row = rect.top; row <= rect.bottom; row++) {
    for (let col = rect.left; col <= rect.right; col++) {
      const cell = grid.rows[row]?.cells[col];
      if (!cell) {
        continue;
      }

      const index = alongRow ? col : row;
      const classes = ["is-structural-target", `--axis-${target.kind}`];

      if (index === first) {
        classes.push("--edge-start");
      }
      if (index === last) {
        classes.push("--edge-end");
      }

      const pos = target.tablePos + 1 + cell.offset;
      decorations.push(
        Decoration.node(pos, pos + cell.node.nodeSize, {
          class: classes.join(" "),
        })
      );
    }
  }

  return decorations;
}

function gripDecoration(pos, kind, pluginParams, activeGestures, options = {}) {
  return Decoration.widget(
    pos,
    (view, getPos) =>
      buildGrip(kind, view, getPos, pluginParams, activeGestures, options),
    {
      side: -1,
      key: `table-grip-${kind}${options.header ? "-header" : ""}`,
      ignoreSelection: true,
      stopEvent: () => true,
    }
  );
}

function buildGrip(kind, view, getPos, pluginParams, activeGestures, options) {
  const grip = document.createElement("button");
  grip.type = "button";
  grip.className = `composer-table__grip --${kind}`;
  grip.contentEditable = "false";
  grip.draggable = false;
  grip.tabIndex = -1;
  grip.setAttribute("aria-expanded", "false");
  grip.setAttribute(
    "aria-label",
    i18n(
      kind === "row"
        ? "composer.table.select_row"
        : "composer.table.select_column"
    )
  );

  if (options.header) {
    grip.classList.add("--header");
  }

  // Pointer events carry the drag and open the menu on release. A click handler
  // remains for assistive technology that synthesizes activation directly.
  const context = {
    kind,
    view,
    getPos,
    pluginParams,
    activeGestures,
    grip,
    dragged: false,
    openedFromPointer: false,
  };
  grip.addEventListener("mousedown", (event) => event.preventDefault());
  grip.addEventListener("pointerdown", (event) =>
    onGripPointerDown(event, context)
  );
  grip.addEventListener("click", (event) => onGripClick(event, context));

  return grip;
}

function onGripPointerDown(event, context) {
  if (!context.view.editable || event.button !== 0) {
    return;
  }
  event.preventDefault();
  context.dragged = false;
  context.openedFromPointer = false;

  const target = locateGrip(context);
  if (!target) {
    return;
  }

  highlightAt(context.view, target, context.kind);
  trackDrag(event, context, target);
}

// An assistive click has no pointer press to establish the target first.
function onGripClick(event, context) {
  if (!context.view.editable) {
    return;
  }

  if (context.openedFromPointer) {
    context.openedFromPointer = false;
    return;
  }

  if (context.dragged) {
    context.dragged = false;
    return;
  }

  const target = locateGrip(context);
  if (!target) {
    return;
  }

  highlightAt(context.view, target, context.kind);
  openGripMenu(context, target);
}

/** The table, row and column the grip currently belongs to. */
function locateGrip({ view, getPos }) {
  const pos = getPos();
  if (pos === undefined) {
    return null;
  }

  const $cell = cellAround(view.state.doc.resolve(pos));
  if (!$cell) {
    return null;
  }

  const table = findTable($cell);
  const coords = cellCoords(table.grid, $cell.pos - table.start);
  return coords ? { table, ...coords } : null;
}

function highlightAt(view, { table, row, col }, kind) {
  view.dispatch(
    view.state.tr.setMeta(TABLE_CHROME_KEY, {
      tablePos: table.pos,
      kind,
      index: kind === "row" ? row : col,
    })
  );
}

function trackDrag(startEvent, context, target) {
  const { activeGestures, kind, grip, view } = context;
  const { pointerId } = startEvent;
  const inner = grip.closest(".composer-table__inner");
  const indicator = inner?.querySelector(".composer-table__drop-indicator");
  const grid = inner?.querySelector("table");
  if (!inner || !grid) {
    return;
  }

  const axis = kind === "row" ? "Y" : "X";
  const origin = kind === "row" ? startEvent.clientY : startEvent.clientX;
  const index = kind === "row" ? target.row : target.col;
  const dragThreshold =
    startEvent.pointerType === "touch" ? TOUCH_DRAG_THRESHOLD : DRAG_THRESHOLD;

  // Geometry is read once. The dragged row or column follows the pointer while
  // the gesture runs, so measuring again mid-drag would read its own offset
  // back and chase itself.
  const spans = measureSpans(inner, grid, kind);
  const forward = spanDirection(spans);
  const moving =
    kind === "row"
      ? [...(grid.rows[index]?.cells ?? [])]
      : [...grid.rows].map((row) => row.cells[index]).filter(Boolean);

  let dragging = false;
  let dropIndex = null;
  let current = origin;
  let avatar = null;
  let stopped = false;
  const updateLanding = () => {
    const over = spanUnderPointer(spans, current, forward);
    dropIndex = over === index ? null : over > index ? over + 1 : over;
    positionIndicator(indicator, kind, spans, dropIndex, forward);
  };

  const autoscroll = dragAutoscroll(inner, axis, (change) => {
    for (const span of spans) {
      span.start -= change;
      span.end -= change;
    }
    updateLanding();
  });

  const lift = (offset) => {
    moving.forEach((cell) => {
      cell.style.transform = `translate${axis}(${offset}px)`;
    });
    if (avatar) {
      avatar.style.transform = `translate${axis}(${offset}px)`;
    }
  };

  const settle = () => {
    moving.forEach((cell) => {
      cell.style.transform = "";
      cell.classList.remove("is-moving");
    });
    avatar?.remove();
    avatar = null;
    grip.classList.remove("is-drag-origin");
    inner.classList.remove("is-reordering");
    if (indicator) {
      indicator.className = "composer-table__drop-indicator";
      indicator.removeAttribute("style");
    }
  };

  const stop = () => {
    if (stopped) {
      return;
    }

    stopped = true;
    document.removeEventListener("pointermove", move);
    document.removeEventListener("pointerup", finish);
    document.removeEventListener("pointercancel", finish);
    activeGestures.delete(stop);
    autoscroll.stop();
    settle();
  };

  const move = (event) => {
    if (event.pointerId !== pointerId) {
      return;
    }

    current = kind === "row" ? event.clientY : event.clientX;
    const offset = current - origin;

    if (!dragging && Math.abs(offset) < dragThreshold) {
      return;
    }

    event.preventDefault();
    if (!dragging) {
      dragging = true;
      inner.classList.add("is-reordering");
      moving.forEach((cell) => cell.classList.add("is-moving"));
      avatar = dragAvatar(grip, kind);
      grip.classList.add("is-drag-origin");
    }

    lift(offset);
    autoscroll.update(event);

    // Landing is decided by which row or column the pointer is over, not by how
    // far past its middle: an insertion index taken from midpoints needs a drag
    // of one and a half columns to move a column by one.
    updateLanding();
  };

  const finish = (event) => {
    if (event.pointerId !== pointerId) {
      return;
    }

    const landed = event.type === "pointercancel" ? null : dropIndex;
    stop();

    if (!dragging && event.type !== "pointercancel") {
      context.openedFromPointer = true;
      requestAnimationFrame(() => {
        const anchorGrip = currentGrip(context, target);
        if (view.editable && anchorGrip.isConnected) {
          openGripMenu({ ...context, grip: anchorGrip }, target);
        }
      });
      return;
    }

    if (dragging) {
      context.dragged = true;

      if (landed !== null) {
        const command =
          kind === "row"
            ? moveRow(index, landed, target.table)
            : moveColumn(index, landed, target.table);
        if (command(view.state, view.dispatch)) {
          announceMove(context, index, landed);
        }
      }
    }
  };

  document.addEventListener("pointermove", move);
  document.addEventListener("pointerup", finish);
  document.addEventListener("pointercancel", finish);
  activeGestures.add(stop);
}

function currentGrip({ kind, grip, view }, target) {
  const table = view.nodeDOM(target.table.pos);
  const index = kind === "row" ? target.row : target.col;

  return table instanceof Element
    ? (table.querySelectorAll(`.composer-table__grip.--${kind}`)[index] ?? grip)
    : grip;
}

function announceMove({ kind, pluginParams, view }, index, landed) {
  const forward = landed > index;
  let key;

  if (kind === "row") {
    key = forward ? "row_moved_down" : "row_moved_up";
  } else {
    const rtl = getComputedStyle(view.dom).direction === "rtl";
    key = forward !== rtl ? "column_moved_right" : "column_moved_left";
  }

  pluginParams.getContext().a11y.announce(i18n(`composer.table.${key}`));
}

function syncGripAccessibility(view) {
  for (const grip of view.dom.querySelectorAll(".composer-table__grip")) {
    const row = grip.closest("tr");
    const cell = grip.closest("th, td");
    const kind = grip.classList.contains("--row") ? "row" : "column";
    const current =
      kind === "row"
        ? cell?.matches(".is-current-row, .is-structural-target.--axis-row")
        : cell?.matches(
            ".is-current-column, .is-structural-target.--axis-column"
          );
    const number = kind === "row" ? row?.rowIndex + 1 : cell?.cellIndex + 1;

    grip.hidden = !view.editable;
    grip.disabled = !view.editable;
    grip.setAttribute("aria-hidden", current ? "false" : "true");
    if (number) {
      grip.setAttribute(
        "aria-label",
        i18n(`composer.table.${kind}_actions`, { number })
      );
    }
  }
}

function dragAvatar(grip, kind) {
  const bounds = grip.getBoundingClientRect();
  const avatar = document.createElement("div");
  avatar.className = `composer-table__drag-avatar --${kind}`;
  avatar.ariaHidden = "true";
  Object.assign(avatar.style, {
    top: `${bounds.top}px`,
    left: `${bounds.left}px`,
    width: `${bounds.width}px`,
    height: `${bounds.height}px`,
  });
  document.body.appendChild(avatar);
  return avatar;
}

/** Start, size and offset within `inner` of every row or column, in order. */
function measureSpans(inner, grid, kind) {
  const bounds = inner.getBoundingClientRect();
  const elements =
    kind === "row" ? [...grid.rows] : [...(grid.rows[0]?.cells ?? [])];

  return elements.map((element) => {
    const box = element.getBoundingClientRect();

    return kind === "row"
      ? {
          start: box.top,
          end: box.bottom,
          offset: box.top - bounds.top,
          size: box.height,
        }
      : {
          start: box.left,
          end: box.right,
          offset: box.left - bounds.left,
          size: box.width,
        };
  });
}

/** +1 when the axis grows with the index, -1 for columns in RTL. */
function spanDirection(spans) {
  if (spans.length < 2) {
    return 1;
  }

  const first = spans[0];
  const last = spans[spans.length - 1];
  return Math.sign(last.start + last.end - (first.start + first.end)) || 1;
}

function spanUnderPointer(spans, position, forward) {
  if (!spans.length) {
    return 0;
  }

  const found = spans.findIndex(
    (span) => position >= span.start && position < span.end
  );
  if (found !== -1) {
    return found;
  }

  const firstCenter = (spans[0].start + spans[0].end) / 2;
  return (position - firstCenter) * forward < 0 ? 0 : spans.length - 1;
}

function positionIndicator(indicator, kind, spans, dropIndex, forward) {
  if (!indicator) {
    return;
  }

  if (dropIndex === null) {
    indicator.className = "composer-table__drop-indicator";
    indicator.removeAttribute("style");
    return;
  }

  const after = dropIndex > 0 ? spans[dropIndex - 1] : null;
  const edge = after
    ? after.offset + (forward > 0 ? after.size : 0)
    : spans[0].offset + (forward > 0 ? 0 : spans[0].size);

  indicator.className = `composer-table__drop-indicator --${kind}`;
  if (kind === "row") {
    indicator.style.top = `${edge}px`;
  } else {
    indicator.style.left = `${edge}px`;
  }
}
