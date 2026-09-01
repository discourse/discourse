const CELL_ROLES = ["cell", "header_cell"];

const gridCache = new WeakMap();

export function isCell(node) {
  return CELL_ROLES.includes(node?.type.spec.tableRole);
}

export function isTable(node) {
  return node?.type.spec.tableRole === "table";
}

/**
 * Flattened geometry of a table.
 *
 * Markdown tables never merge cells, so a normalized grid is a plain rectangle
 * and a cell can be addressed by `(row, col)` alone. Offsets are relative to the
 * table's content start, which keeps the result cacheable per node.
 *
 * @param {import("prosemirror-model").Node} table
 * @returns {{
 *   rows: { node: import("prosemirror-model").Node, offset: number, header: boolean,
 *           cells: { node: import("prosemirror-model").Node, offset: number }[] }[],
 *   head: { node: import("prosemirror-model").Node, offset: number } | null,
 *   body: { node: import("prosemirror-model").Node, offset: number } | null,
 *   width: number,
 *   height: number,
 * }}
 */
export function tableGrid(table) {
  const cached = gridCache.get(table);
  if (cached) {
    return cached;
  }

  const rows = [];
  let head = null;
  let body = null;
  let sectionOffset = 0;

  table.forEach((section) => {
    const header = section.type.spec.tableRole === "head";
    if (header) {
      head = { node: section, offset: sectionOffset };
    } else {
      body = { node: section, offset: sectionOffset };
    }

    let rowOffset = sectionOffset + 1;
    section.forEach((row) => {
      const cells = [];
      let cellOffset = rowOffset + 1;
      row.forEach((cell) => {
        cells.push({ node: cell, offset: cellOffset });
        cellOffset += cell.nodeSize;
      });
      rows.push({ node: row, offset: rowOffset, header, cells });
      rowOffset += row.nodeSize;
    });

    sectionOffset += section.nodeSize;
  });

  const grid = {
    rows,
    head,
    body,
    height: rows.length,
    width: rows.reduce((max, row) => Math.max(max, row.cells.length), 0),
  };

  gridCache.set(table, grid);
  return grid;
}

/**
 * The table enclosing a resolved position, if any.
 *
 * @param {import("prosemirror-model").ResolvedPos} $pos
 * @returns {{ node: import("prosemirror-model").Node, pos: number, start: number,
 *            grid: ReturnType<typeof tableGrid> } | null}
 */
export function findTable($pos) {
  for (let depth = $pos.depth; depth > 0; depth--) {
    const node = $pos.node(depth);
    if (isTable(node)) {
      return {
        node,
        pos: $pos.before(depth),
        start: $pos.start(depth),
        grid: tableGrid(node),
      };
    }
  }
  return null;
}

/**
 * Resolves to the position *before* the cell enclosing `$pos`.
 *
 * @param {import("prosemirror-model").ResolvedPos} $pos
 * @returns {import("prosemirror-model").ResolvedPos | null}
 */
export function cellAround($pos) {
  for (let depth = $pos.depth; depth > 0; depth--) {
    if (isCell($pos.node(depth))) {
      return $pos.doc.resolve($pos.before(depth));
    }
  }
  return null;
}

export function cellCoords(grid, offset) {
  for (let row = 0; row < grid.rows.length; row++) {
    const col = grid.rows[row].cells.findIndex(
      (cell) => cell.offset === offset
    );
    if (col !== -1) {
      return { row, col };
    }
  }
  return null;
}

export function rowRange(table, row) {
  const { node, offset } = table.grid.rows[row];
  return {
    from: table.start + offset,
    to: table.start + offset + node.nodeSize,
  };
}
