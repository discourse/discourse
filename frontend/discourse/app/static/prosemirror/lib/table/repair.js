import { Fragment } from "prosemirror-model";
import { cellType, isTable, tableGrid } from "./grid";

/** Repairs malformed table structures within a document range. */
export function fixTables(state, tr, from = 0, to = state.doc.content.size) {
  const tables = [];
  state.doc.nodesBetween(from, to, (node, pos) => {
    if (!node.isBlock) {
      return false;
    }
    if (isTable(node)) {
      tables.push({ node, pos });
      return false;
    }
  });

  let result = tr;
  // Bottom-up, so positions read from the untouched document stay valid.
  for (let index = tables.length - 1; index >= 0; index--) {
    result = fixTable(state, tables[index], result);
  }

  return result;
}

function fixTable(state, { node, pos }, tr) {
  const schema = state.schema;
  const grid = tableGrid(node);
  const start = pos + 1;
  let result = tr;

  if (!grid.height) {
    result ??= state.tr;
    result.replaceWith(
      pos,
      pos + node.nodeSize,
      schema.nodes.paragraph.createAndFill()
    );
    return result;
  }

  for (const row of grid.rows) {
    const expected = cellType(schema, row.header);

    for (const cell of row.cells) {
      if (cell.node.type !== expected) {
        result ??= state.tr;
        result.setNodeMarkup(start + cell.offset, expected, cell.node.attrs);
      }
    }
  }

  // Padding is applied bottom-up: cell type fixes above never move positions.
  for (let index = grid.rows.length - 1; index >= 0; index--) {
    const row = grid.rows[index];
    const missing = grid.width - row.cells.length;
    if (missing <= 0) {
      continue;
    }

    const type = cellType(schema, row.header);
    const cells = Array.from({ length: missing }, (_, offset) =>
      type.createAndFill({
        alignment:
          grid.rows[0]?.cells[row.cells.length + offset]?.node.attrs
            .alignment ?? null,
      })
    );

    result ??= state.tr;
    result.insert(
      start + row.offset + row.node.nodeSize - 1,
      Fragment.from(cells)
    );
  }

  return result;
}
