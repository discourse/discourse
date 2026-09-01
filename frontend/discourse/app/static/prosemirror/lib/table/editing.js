import { Plugin, TextSelection } from "prosemirror-state";
import { Decoration, DecorationSet } from "prosemirror-view";
import { currentCell, goToNextCell } from "./commands";
import { cellAround, findTable } from "./grid";
import handleTablePaste from "./paste";
import { fixTables } from "./repair";

/**
 * Cell-aware keyboard navigation and repair for structures that generic
 * editing would otherwise leave ragged.
 */
export default function tableEditing() {
  return new Plugin({
    props: {
      decorations: selectionDecorations,
      handleKeyDown,
      handlePaste,
      handleTextInput: (view, from, to, text) =>
        replaceCrossCellSelection(view, { text }),
      handleDOMEvents: {
        beforeinput: handleBeforeInput,
        cut: handleCut,
        keydown: handleDeleteKeyDown,
      },
    },

    appendTransaction(transactions, oldState, newState) {
      const docChanged = transactions.some((tr) => tr.docChanged);
      if (docChanged && !onlyCellContentChanged(oldState.doc, newState.doc)) {
        return fixTables(newState, null);
      }
      return null;
    },
  });
}

function crossCellRange(state) {
  const { selection } = state;
  if (!(selection instanceof TextSelection) || selection.empty) {
    return null;
  }

  const $fromCell = cellAround(selection.$from);
  const $toCell = cellAround(selection.$to);
  if (!$fromCell || !$toCell || $fromCell.pos === $toCell.pos) {
    return null;
  }

  const table = findTable($fromCell);
  const endTable = findTable($toCell);
  return table && endTable?.pos === table.pos ? table : null;
}

function replaceCrossCellSelection(view, { text, slice, meta } = {}) {
  if (!view.editable) {
    return false;
  }

  const { state } = view;
  const { selection } = state;
  const table = crossCellRange(state);
  if (!table) {
    return false;
  }

  const ranges = [];
  for (const row of table.grid.rows) {
    for (const cell of row.cells) {
      const start = table.start + cell.offset + 1;
      const end = start + cell.node.content.size;
      const from = Math.max(selection.from, start);
      const to = Math.min(selection.to, end);
      if (from < to) {
        ranges.push({ from, to });
      }
    }
  }

  const tr = state.tr;
  for (let index = ranges.length - 1; index >= 0; index--) {
    tr.delete(ranges[index].from, ranges[index].to);
  }

  tr.setSelection(
    TextSelection.create(tr.doc, tr.mapping.map(selection.from, -1))
  );

  if (text !== undefined) {
    tr.insertText(text);
  } else if (slice) {
    tr.replaceSelection(slice);
  }

  if (meta) {
    for (const [key, value] of Object.entries(meta)) {
      tr.setMeta(key, value);
    }
  }

  view.dispatch(tr.scrollIntoView());
  return true;
}

function handlePaste(view, event, slice) {
  if (handleTablePaste(view, event, slice)) {
    return true;
  }

  return replaceCrossCellSelection(view, {
    slice,
    meta: { paste: true, uiEvent: "paste" },
  });
}

function handleBeforeInput(view, event) {
  if (!event.inputType?.startsWith("delete")) {
    return false;
  }

  const handled = replaceCrossCellSelection(view);
  if (handled) {
    event.preventDefault();
  }
  return handled;
}

function handleCut(view, event) {
  if (!crossCellRange(view.state) || !event.clipboardData) {
    return false;
  }

  const { dom, text } = view.serializeForClipboard(
    view.state.selection.content()
  );
  event.preventDefault();
  event.clipboardData.clearData();
  event.clipboardData.setData("text/html", dom.innerHTML);
  event.clipboardData.setData("text/plain", text);
  return replaceCrossCellSelection(view);
}

function handleDeleteKeyDown(view, event) {
  if (event.key !== "Backspace" && event.key !== "Delete") {
    return false;
  }

  const handled = replaceCrossCellSelection(view);
  if (handled) {
    event.preventDefault();
  }
  return handled;
}

function onlyCellContentChanged(oldDoc, newDoc) {
  const start = oldDoc.content.findDiffStart(newDoc.content);
  if (start === null) {
    return true;
  }

  const end = oldDoc.content.findDiffEnd(newDoc.content);
  if (!end) {
    return false;
  }

  return (
    changeInsideOneCell(oldDoc, start, end.a) &&
    changeInsideOneCell(newDoc, start, end.b)
  );
}

function changeInsideOneCell(doc, from, to) {
  const safeFrom = Math.min(from, doc.content.size);
  const safeTo = Math.min(Math.max(to, safeFrom), doc.content.size);
  const $from = cellAround(doc.resolve(safeFrom));
  const $to = cellAround(doc.resolve(safeTo));

  return (
    $from &&
    $to &&
    $from.pos === $to.pos &&
    safeFrom > $from.pos &&
    safeTo < $from.pos + $from.nodeAfter.nodeSize
  );
}

function selectionDecorations(state) {
  const decorations = [];
  const current = currentCell(state);

  // Touch input uses the active table to reveal controls without hover. This
  // class must not change with the selection: a node decoration on the table
  // redraws its whole content, which would rebuild every grip widget inside it.
  if (current) {
    decorations.push(
      Decoration.node(current.pos, current.pos + current.node.nodeSize, {
        class: "is-active",
      })
    );

    const currentRow = current.grid.rows[current.rect.top];
    const rowCell = currentRow?.cells[0];
    const columnCell = current.grid.rows[0]?.cells[current.rect.left];

    if (rowCell) {
      decorations.push(
        Decoration.node(
          current.start + rowCell.offset,
          current.start + rowCell.offset + rowCell.node.nodeSize,
          { class: "is-current-row" }
        )
      );
    }
    if (columnCell) {
      decorations.push(
        Decoration.node(
          current.start + columnCell.offset,
          current.start + columnCell.offset + columnCell.node.nodeSize,
          { class: "is-current-column" }
        )
      );
    }
  }

  return decorations.length
    ? DecorationSet.create(state.doc, decorations)
    : null;
}

function handleKeyDown(view, event) {
  if (!view.editable) {
    return false;
  }

  const { state } = view;

  if (event.key === "Tab") {
    if (!currentCell(state)) {
      return false;
    }
    event.preventDefault();
    return goToNextCell(event.shiftKey ? -1 : 1)(state, view.dispatch, view);
  }

  return false;
}
