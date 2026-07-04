// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  parsePlacement,
} from "discourse/lib/blocks";
import { i18n } from "discourse-i18n";

/**
 * A data table whose cells hold arbitrary child blocks. Each cell is a child
 * entry positioned by `containerArgs.grid` (the SAME placement shape a grid
 * `layout` uses), so the table reuses the shared grid placement helpers rather
 * than inventing a second positioning model. Children without an explicit
 * placement auto-fill the remaining cells in reading order, so dropping blocks
 * in fills the table row by row without any per-cell setup.
 *
 * The table renders as semantic `<table>` markup with optional header row and
 * header column (`<th scope>`), and column / row spans map to `colspan` /
 * `rowspan`. A single block per cell is the rule; for several blocks in one
 * cell, place a container (a `group`, say) there.
 */
@block("table", {
  thumbnail:
    /** @type {() => Promise<typeof import("discourse/blocks/thumbnails/table.gjs")>} */ (
      () => import("discourse/blocks/thumbnails/table")
    ),
  container: true,
  // Marks this container as positionable on a 2D grid, so editing tooling can
  // offer the same cell-placement affordances it offers any grid container.
  gridEditable: true,
  displayName: "Table",
  icon: "table",
  category: "Layout",
  description: "A table whose cells hold blocks, with optional headers.",
  args: {
    columns: {
      type: "number",
      default: DEFAULT_GRID_COLUMNS,
      integer: true,
      min: 1,
      max: 24,
      ui: { label: i18n("blocks.builtin.table.columns") },
    },
    rows: {
      type: "number",
      default: DEFAULT_GRID_ROWS,
      integer: true,
      min: 1,
      max: 50,
      ui: { label: i18n("blocks.builtin.table.rows") },
    },
    headerRow: {
      type: "boolean",
      default: false,
      ui: { control: "toggle", label: i18n("blocks.builtin.table.header_row") },
    },
    headerColumn: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.table.header_column"),
      },
    },
  },
  childArgs: {
    grid: {
      type: "object",
      default: { column: "auto", row: "auto" },
      properties: {
        column: {
          type: "string",
          default: "auto",
          ui: { label: i18n("blocks.builtin.table.cell_column") },
        },
        row: {
          type: "string",
          default: "auto",
          ui: { label: i18n("blocks.builtin.table.cell_row") },
        },
      },
      ui: { label: i18n("blocks.builtin.table.cell_placement") },
    },
  },
})
export default class Table extends Component {
  /**
   * Builds the rendered table model: a dense `rows × columns` matrix of cells.
   * Explicitly-placed children occupy their rect (with col / row spans);
   * unplaced children fill the remaining cells in reading order; cells with no
   * child render empty. Cells covered by a spanning neighbour are omitted (the
   * spanning cell carries the `colspan` / `rowspan`).
   *
   * @returns {Array<{key: string, cells: Array<Object>}>}
   */
  get tableModel() {
    const children = this.args.children ?? [];
    const { columns, rows } = gridDimensions(
      {
        columns: this.args.columns ?? DEFAULT_GRID_COLUMNS,
        rows: this.args.rows ?? DEFAULT_GRID_ROWS,
      },
      children
    );

    const occupied = Array.from({ length: rows }, () =>
      new Array(columns).fill(false)
    );
    // Top-left cell descriptor keyed by "r,c".
    const cellMap = new Map();
    const autoChildren = [];

    const occupy = (r, c, rowspan, colspan) => {
      for (let rr = r; rr < r + rowspan && rr < rows; rr++) {
        for (let cc = c; cc < c + colspan && cc < columns; cc++) {
          occupied[rr][cc] = true;
        }
      }
    };

    for (const child of children) {
      const { column, row } = parsePlacement(child.containerArgs);
      if (column.start != null && row.start != null) {
        const c = column.start - 1;
        const r = row.start - 1;
        if (r >= rows || c >= columns) {
          continue;
        }
        const colspan = Math.min(
          (column.end ?? column.start + 1) - column.start,
          columns - c
        );
        const rowspan = Math.min(
          (row.end ?? row.start + 1) - row.start,
          rows - r
        );
        cellMap.set(`${r},${c}`, { r, c, rowspan, colspan, child });
        occupy(r, c, rowspan, colspan);
      } else {
        autoChildren.push(child);
      }
    }

    // Auto-place the unplaced children, one per free cell, in reading order.
    let next = 0;
    for (let r = 0; r < rows && next < autoChildren.length; r++) {
      for (let c = 0; c < columns && next < autoChildren.length; c++) {
        if (!occupied[r][c]) {
          occupied[r][c] = true;
          cellMap.set(`${r},${c}`, {
            r,
            c,
            rowspan: 1,
            colspan: 1,
            child: autoChildren[next++],
          });
        }
      }
    }

    // Mark every non-top-left cell of a span so the renderer skips it.
    const covered = Array.from({ length: rows }, () =>
      new Array(columns).fill(false)
    );
    for (const cell of cellMap.values()) {
      for (let rr = cell.r; rr < cell.r + cell.rowspan; rr++) {
        for (let cc = cell.c; cc < cell.c + cell.colspan; cc++) {
          if (rr !== cell.r || cc !== cell.c) {
            covered[rr][cc] = true;
          }
        }
      }
    }

    const headerRow = this.args.headerRow ?? false;
    const headerColumn = this.args.headerColumn ?? false;
    const out = [];
    for (let r = 0; r < rows; r++) {
      const cells = [];
      for (let c = 0; c < columns; c++) {
        if (covered[r][c]) {
          continue;
        }
        const placed = cellMap.get(`${r},${c}`);
        const isHeader = (headerRow && r === 0) || (headerColumn && c === 0);
        let scope = null;
        if (isHeader) {
          scope = headerRow && r === 0 ? "col" : "row";
        }
        cells.push({
          key: placed ? placed.child.key : `empty-${r}-${c}`,
          child: placed?.child ?? null,
          colspan: placed?.colspan ?? 1,
          rowspan: placed?.rowspan ?? 1,
          isHeader,
          scope,
        });
      }
      out.push({ key: `row-${r}`, cells });
    }
    return out;
  }

  <template>
    <table class="d-block-table">
      <tbody>
        {{#each this.tableModel key="key" as |row|}}
          <tr>
            {{#each row.cells key="key" as |cell|}}
              {{#if cell.isHeader}}
                <th
                  scope={{cell.scope}}
                  colspan={{cell.colspan}}
                  rowspan={{cell.rowspan}}
                >
                  {{#if cell.child}}<cell.child.Component />{{/if}}
                </th>
              {{else}}
                <td colspan={{cell.colspan}} rowspan={{cell.rowspan}}>
                  {{#if cell.child}}<cell.child.Component />{{/if}}
                </td>
              {{/if}}
            {{/each}}
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
