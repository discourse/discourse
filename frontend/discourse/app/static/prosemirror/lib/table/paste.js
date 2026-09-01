import { Fragment } from "prosemirror-model";
import { currentCell } from "./commands";
import { isTable, tableGrid } from "./grid";

// A table pasted into a cell can't nest, so its cells are written into the grid
// starting at the target cell, growing the table when the paste overflows it.
export default function handlePaste(view, event, slice) {
  const table = currentCell(view.state);
  if (!table) {
    return false;
  }

  const rows = pastedRows(slice);
  if (!rows) {
    return false;
  }

  const { state } = view;
  const schema = state.schema;
  const { top, left } = table.rect;
  const width = Math.max(
    table.grid.width,
    left + Math.max(...rows.map((row) => row.length))
  );
  const height = Math.max(table.grid.height, top + rows.length);

  const built = [];
  for (let row = 0; row < height; row++) {
    const source = table.grid.rows[row];
    const header = row === 0 && !!table.grid.head;
    const type = header
      ? schema.nodes.table_header_cell
      : schema.nodes.table_cell;
    const cells = [];

    for (let col = 0; col < width; col++) {
      const alignment =
        table.grid.rows[0]?.cells[col]?.node.attrs.alignment ?? null;
      const incoming =
        col >= left && row >= top ? rows[row - top]?.[col - left] : undefined;
      const existing = source?.cells[col]?.node;

      if (incoming) {
        cells.push(
          type.create({ alignment }, incoming.content, incoming.marks)
        );
      } else if (existing) {
        cells.push(
          type.create(existing.attrs, existing.content, existing.marks)
        );
      } else {
        cells.push(type.createAndFill({ alignment }));
      }
    }

    built.push(schema.nodes.table_row.create(null, Fragment.from(cells)));
  }

  const sections = [];
  if (table.grid.head) {
    sections.push(schema.nodes.table_head.create(null, built[0]));
  }
  sections.push(
    schema.nodes.table_body.create(
      null,
      Fragment.from(built.slice(table.grid.head ? 1 : 0))
    )
  );

  view.dispatch(
    state.tr.replaceWith(
      table.pos,
      table.pos + table.node.nodeSize,
      schema.nodes.table.create(table.node.attrs, Fragment.from(sections))
    )
  );
  return true;
}

function pastedRows(slice) {
  const table = slice.content.childCount === 1 && slice.content.firstChild;
  if (!table || !isTable(table)) {
    return null;
  }

  return tableGrid(table).rows.map((row) => row.cells.map((cell) => cell.node));
}
