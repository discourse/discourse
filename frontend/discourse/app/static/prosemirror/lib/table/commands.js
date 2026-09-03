import { Fragment } from "prosemirror-model";
import { TextSelection } from "prosemirror-state";
import {
  cellAround,
  cellCoords,
  cellType,
  copyCell,
  findTable,
  rowRange,
} from "./grid";

export const ALIGNMENTS = ["left", "center", "right"];

/**
 * The table and cell containing the start of the current text selection, or
 * null when it is outside a table.
 */
export function currentCell(state) {
  const { selection } = state;
  const $cell = cellAround(selection.$from);

  if (!$cell) {
    return null;
  }

  const table = findTable($cell);
  if (!table) {
    return null;
  }

  const coords = cellCoords(table.grid, $cell.pos - table.start);
  if (!coords) {
    return null;
  }

  return {
    ...table,
    rect: {
      top: coords.row,
      bottom: coords.row,
      left: coords.col,
      right: coords.col,
    },
  };
}

/**
 * A command over `target`, or over the table the caret is in when no target is
 * given. `apply` builds the transaction and may return null to dispatch
 * nothing; `enabled` rejects the command before it is dispatched.
 */
function tableCommand(target, apply, enabled) {
  return (state, dispatch) => {
    const table = target ?? currentCell(state);
    if (!table || enabled?.(table) === false) {
      return false;
    }

    if (dispatch) {
      const tr = apply(state.tr, table);
      if (tr) {
        dispatch(tr);
      }
    }
    return true;
  };
}

/**
 * Trailing columns whose every cell is empty, and so can be dropped without
 * losing anything. At least one column always stays.
 */
export function emptyTrailingColumns(grid) {
  let count = 0;

  for (let col = grid.width - 1; col > 0; col--) {
    const empty = grid.rows.every((row) => isEmptyCell(row.cells[col]));
    if (!empty) {
      break;
    }
    count++;
  }

  return count;
}

/** The same for body rows. A header-only table is still a valid table. */
export function emptyTrailingRows(grid) {
  const body = grid.rows.filter((row) => !row.header);
  let count = 0;

  for (let index = body.length - 1; index >= 0; index--) {
    const empty = body[index].cells.every(isEmptyCell);
    if (!empty) {
      break;
    }
    count++;
  }

  return count;
}

function isEmptyCell(cell) {
  return !cell || cell.node.content.size === 0;
}

export function columnAlignment(table, col) {
  return table.grid.rows[0]?.cells[col]?.node.attrs.alignment ?? null;
}

export function addColumn(side, target, count = 1) {
  return tableCommand(target, (tr, table) =>
    insertColumn(
      tr,
      table,
      side < 0 ? table.rect.left : table.rect.right + 1,
      count
    ).scrollIntoView()
  );
}

export function deleteColumn(target) {
  return tableCommand(target, (tr, table) => {
    const { left, right } = table.rect;

    if (right - left + 1 >= table.grid.width) {
      return tr.delete(table.pos, table.pos + table.node.nodeSize);
    }

    forEachRowBottomUp(table, (row) => {
      for (let col = right; col >= left; col--) {
        const cell = row.cells[col];
        if (cell) {
          tr.delete(
            table.start + cell.offset,
            table.start + cell.offset + cell.node.nodeSize
          );
        }
      }
    });

    return tr;
  });
}

export function duplicateColumn(target) {
  return tableCommand(target, (tr, table) => {
    const { left, right } = table.rect;

    forEachRowBottomUp(table, (row) => {
      const copies = [];
      for (let col = left; col <= right; col++) {
        const cell = row.cells[col].node;
        copies.push(copyCell(cell.type, cell));
      }
      const ref = row.cells[right];
      tr.insert(
        table.start + ref.offset + ref.node.nodeSize,
        Fragment.from(copies)
      );
    });

    return tr.scrollIntoView();
  });
}

/**
 * @param {number} from index of the column to move
 * @param {number} to insertion index, in the coordinates of the unmoved grid
 */
export function moveColumn(from, to, tableTarget) {
  return tableCommand(
    tableTarget,
    (tr, table) => {
      const target = to > from ? to - 1 : to;

      forEachRowBottomUp(table, (row) => {
        const cells = row.cells.map((cell) => cell.node);
        const [moved] = cells.splice(from, 1);
        cells.splice(target, 0, moved);
        tr.replaceWith(
          table.start + row.offset + 1,
          table.start + row.offset + row.node.nodeSize - 1,
          Fragment.from(cells)
        );
      });

      return tr;
    },
    () => to !== from && to !== from + 1
  );
}

export function setColumnAlignment(alignment, target) {
  return tableCommand(target, (tr, table) => {
    for (const row of table.grid.rows) {
      for (let col = table.rect.left; col <= table.rect.right; col++) {
        const cell = row.cells[col];
        if (cell) {
          tr.setNodeMarkup(table.start + cell.offset, null, {
            ...cell.node.attrs,
            alignment,
          });
        }
      }
    }

    return tr;
  });
}

export function addRow(side, target, count = 1) {
  return tableCommand(
    target,
    (tr, table) => {
      const offset = headOffset(table.grid);
      const index =
        side < 0
          ? Math.max(table.rect.top - offset, 0)
          : table.rect.bottom - offset + 1;

      const pos = insertRow(tr, table, index, count);
      return selectCellContent(tr, pos + 1).scrollIntoView();
    },
    (table) => !!table.grid.body
  );
}

export function deleteRow(target) {
  return tableCommand(target, (tr, table) =>
    removeRows(tr, table, table.rect.top, table.rect.bottom)
  );
}

export function duplicateRow(target) {
  return tableCommand(
    target,
    (tr, table) => {
      const { top, bottom } = table.rect;
      const schema = table.node.type.schema;
      const copies = [];

      for (let index = top; index <= bottom; index++) {
        const row = table.grid.rows[index];
        const cells = [];
        row.node.forEach((cell) => {
          // A duplicated header row becomes a regular row: markdown allows only one.
          const type = row.header ? schema.nodes.table_cell : cell.type;
          cells.push(copyCell(type, cell));
        });
        copies.push(schema.nodes.table_row.create(null, Fragment.from(cells)));
      }

      tr.insert(
        bodyInsertPos(table, bottom - headOffset(table.grid) + 1),
        Fragment.from(copies)
      );

      return tr.scrollIntoView();
    },
    (table) => !!table.grid.body
  );
}

/**
 * @param {number} from index of the row to move
 * @param {number} to insertion index, in the coordinates of the unmoved grid
 */
export function moveRow(from, to, tableTarget) {
  return tableCommand(
    tableTarget,
    (tr, table) => {
      // Markdown pins the header to the first row, not to a particular row's
      // contents, so a move across that boundary is expressible: whichever row
      // lands first becomes the header and its cells change type to match.
      if (table.grid.head && (from === 0 || to === 0)) {
        return reorderAcrossHeader(tr, table, from, to);
      }

      const range = rowRange(table, from);
      const target = bodyInsertPos(table, to - headOffset(table.grid));

      tr.delete(range.from, range.to);
      tr.insert(tr.mapping.map(target), table.grid.rows[from].node);

      return tr;
    },
    (table) => to !== from && to !== from + 1 && !!table.grid.rows[from]
  );
}

/**
 * Rebuilds the table with the rows in their new order. Crossing the header
 * boundary re-types every cell in the rows that swap sections, which is simpler
 * and safer to express as one replacement than as surgery across two sections.
 */
function reorderAcrossHeader(tr, table, from, to) {
  const schema = table.node.type.schema;
  const order = table.grid.rows.map((row) => row.node);
  const [moved] = order.splice(from, 1);
  const landing = to > from ? to - 1 : to;
  order.splice(landing, 0, moved);

  const rows = order.map((row, index) => {
    const type = cellType(schema, index === 0);
    const cells = [];
    row.forEach((cell) => cells.push(copyCell(type, cell)));
    return schema.nodes.table_row.create(null, Fragment.from(cells));
  });

  const replacement = schema.nodes.table.create(table.node.attrs, [
    schema.nodes.table_head.create(null, rows[0]),
    schema.nodes.table_body.create(null, Fragment.from(rows.slice(1))),
  ]);

  return tr.replaceWith(
    table.pos,
    table.pos + table.node.nodeSize,
    replacement
  );
}

export function deleteTable(target) {
  return tableCommand(target, (tr, table) =>
    tr.delete(table.pos, table.pos + table.node.nodeSize)
  );
}

export function goToNextCell(dir) {
  return (state, dispatch) => {
    const table = currentCell(state);
    if (!table) {
      return false;
    }

    const $cell = cellAround(state.selection.$from);
    const coords = cellCoords(table.grid, $cell.pos - table.start);
    if (!coords) {
      return false;
    }

    const { grid } = table;
    const index = coords.row * grid.width + coords.col + dir;

    if (index < 0) {
      return false;
    }

    if (index >= grid.width * grid.height) {
      if (dir < 0 || !grid.body) {
        return false;
      }

      if (dispatch) {
        const tr = state.tr;
        const pos = insertRow(tr, table, grid.height - headOffset(grid));
        dispatch(selectCellContent(tr, pos + 1).scrollIntoView());
      }
      return true;
    }

    if (dispatch) {
      const row = Math.floor(index / grid.width);
      const col = index % grid.width;
      dispatch(
        selectCellContent(
          state.tr,
          table.start + grid.rows[row].cells[col].offset
        ).scrollIntoView()
      );
    }
    return true;
  };
}

export function clearCellContents(target) {
  return tableCommand(target, (tr, table) => {
    const cells = [];
    for (let row = table.rect.top; row <= table.rect.bottom; row++) {
      for (let col = table.rect.left; col <= table.rect.right; col++) {
        const cell = table.grid.rows[row]?.cells[col];
        if (cell) {
          cells.push({ node: cell.node, pos: table.start + cell.offset });
        }
      }
    }

    for (let index = cells.length - 1; index >= 0; index--) {
      const { node, pos } = cells[index];
      if (node.content.size) {
        tr.delete(pos + 1, pos + node.nodeSize - 1);
      }
    }

    return tr.docChanged ? tr : null;
  });
}

function headOffset(grid) {
  return grid.head ? 1 : 0;
}

function forEachRowBottomUp(table, f) {
  for (let index = table.grid.rows.length - 1; index >= 0; index--) {
    f(table.grid.rows[index], index);
  }
}

function insertColumn(tr, table, col, count = 1) {
  const schema = table.node.type.schema;

  forEachRowBottomUp(table, (row) => {
    const last = row.cells[row.cells.length - 1];
    const at =
      col >= row.cells.length
        ? table.start + last.offset + last.node.nodeSize
        : table.start + row.cells[col].offset;

    const cells = Array.from({ length: count }, () =>
      cellType(schema, row.header).createAndFill()
    );
    tr.insert(at, Fragment.from(cells));
  });

  return tr;
}

/** Position where a body row inserted at `bodyIndex` would start. */
function bodyInsertPos(table, bodyIndex) {
  const { start, grid } = table;
  const rows = grid.rows.filter((row) => !row.header);

  if (!rows.length) {
    return start + grid.body.offset + 1;
  }
  if (bodyIndex >= rows.length) {
    const last = rows[rows.length - 1];
    return start + last.offset + last.node.nodeSize;
  }
  return start + rows[Math.max(bodyIndex, 0)].offset;
}

/** Inserts an empty body row and returns the position it starts at. */
function insertRow(tr, table, bodyIndex, count = 1) {
  const schema = table.node.type.schema;
  const cells = [];

  for (let col = 0; col < table.grid.width; col++) {
    cells.push(
      cellType(schema, false).createAndFill({
        alignment: columnAlignment(table, col),
      })
    );
  }

  const pos = bodyInsertPos(table, bodyIndex);
  const rows = Array.from({ length: count }, () =>
    schema.nodes.table_row.create(null, Fragment.from(cells))
  );
  tr.insert(pos, Fragment.from(rows));
  return pos;
}

function removeRows(tr, table, top, bottom) {
  const { grid, start } = table;
  const removingHeader = !!grid.head && top === 0;
  const promoted = removingHeader ? grid.rows[bottom + 1] : null;

  if (removingHeader && !promoted) {
    return tr.delete(table.pos, table.pos + table.node.nodeSize);
  }

  // Highest position first, so the offsets read from the original grid stay valid.
  if (promoted) {
    tr.delete(
      start + promoted.offset,
      start + promoted.offset + promoted.node.nodeSize
    );
  }

  for (let index = bottom; index >= Math.max(top, headOffset(grid)); index--) {
    const row = grid.rows[index];
    tr.delete(start + row.offset, start + row.offset + row.node.nodeSize);
  }

  if (promoted) {
    const schema = table.node.type.schema;
    const headRow = grid.rows[0];
    const cells = [];
    promoted.node.forEach((cell) =>
      cells.push(copyCell(cellType(schema, true), cell))
    );

    tr.replaceWith(
      start + headRow.offset + 1,
      start + headRow.offset + headRow.node.nodeSize - 1,
      Fragment.from(cells)
    );
  }

  return tr;
}

function selectCellContent(tr, pos) {
  const cell = tr.doc.nodeAt(pos);
  if (!cell) {
    return tr;
  }

  return tr.setSelection(
    TextSelection.between(
      tr.doc.resolve(pos + 1),
      tr.doc.resolve(pos + cell.nodeSize - 1)
    )
  );
}
