// @ts-check
import Service, { service } from "@ember/service";
import {
  DEFAULT_GRID_COLUMNS,
  DEFAULT_GRID_ROWS,
  gridDimensions,
  LAYOUT_MERGED_CELL_BLOCK,
  parsePlacement,
} from "discourse/blocks";
import {
  matchGridTemplate,
  resolveTemplateLayout,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid/grid-templates";
// `grid-math` holds the editor-only grid geometry. Absolute addon path
// because this admin service crosses into the plugin's universal bundle.
import {
  cellsForFree,
  contentCells,
  reflowChildrenIntoCells,
} from "discourse/plugins/discourse-wireframe/discourse/lib/grid-math";
import {
  entryKey,
  replaceEntryContainerArgs,
  replaceEntryInPlace,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";

/**
 * Owns the whole-grid template / dimension reshaping of a `wf:layout` block —
 * the grid's SHAPE, as opposed to where individual blocks land (that's the grid
 * manipulator's drop chokepoint). Applies a preset template or a free `N×M`
 * grid (reflowing content into the new cells), clamps slot placements to new
 * bounds, and answers the inspector's shape queries (effective size, active
 * template, out-of-bounds slots).
 *
 * A peer command service in the editor's acyclic graph: it injects the
 * mutation/undo engine (records each reshape as one structural-undo entry) and
 * the read-only layout query layer (locating the grid + its resolved layout).
 * It never reaches back into the orchestrator; the orchestrator keeps thin
 * facades so the inspector layout form stays unchanged.
 */
export default class WireframeGridTemplateService extends Service {
  @service wireframeMutationEngine;
  @service wireframeLayoutQuery;

  /**
   * The preset template whose shape matches the given grid's current
   * shape, or `null` when it matches none (which the inspector reads as
   * "Free"). Pure-read; drives the inspector's Free / Template control
   * and the active-preset highlight. Derived from geometry rather than a
   * stored id, so it never goes stale against hand edits.
   *
   * @param {string} gridKey
   * @returns {Object|null}
   */
  activeGridTemplate(gridKey) {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return null;
    }
    const { columns, rows } = this.gridSizeFor(gridKey);
    return matchGridTemplate(located.entry.children ?? [], columns, rows);
  }

  /**
   * Switches a `wf:layout` into free mode at the given dimensions: the
   * grid becomes `columns × rows` single cells and existing content is
   * reflowed into them in reading order. This is the "Free" counterpart
   * to `applyGridTemplate` — picking Free, or changing the column / row
   * count while in Free, both route here so blocks rearrange to fit
   * rather than spilling out of bounds. Refuses when there's more
   * content than `columns × rows` cells.
   *
   * @param {{gridKey: string, columns: number, rows: number}} args
   * @returns {boolean}
   */
  applyFreeGrid({ gridKey, columns, rows }) {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const cells = cellsForFree(columns, rows);
    const content = this.#contentChildren(located.entry);
    if (content.length > cells.length) {
      return false;
    }
    return this.wireframeMutationEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = replaceEntryInPlace(layout, gridKey, {
          ...located.entry,
          // Free mode is even tracks — drop any resized `columnFractions`.
          args: {
            ...located.entry.args,
            mode: "grid",
            columns,
            rows,
            columnFractions: [],
          },
          children: this.#reflowIntoCells(content, cells),
        });
        if (!result.changed) {
          return false;
        }
        this.wireframeMutationEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
  }

  /**
   * Applies a preset grid template to an existing `wf:layout` block.
   * The template resolves to an ordered list of cells (its declared
   * rects). Existing content is reflowed into those cells in reading
   * order; a block dropped into a spanning cell adopts the span.
   * Leftover spanning cells become empty merged-cell entries; leftover
   * single cells are surfaced by the grid overlay. The only refusal is
   * "more content than the template has room for", so switching between
   * templates stays free as long as the content fits — no template
   * disables another just by being applied.
   *
   * Wrapped in a single structural-undo entry so the whole switch
   * can be reverted with one Cmd+Z.
   *
   * @param {{gridKey: string, template: Object}} args
   * @returns {boolean}
   */
  applyGridTemplate({ gridKey, template }) {
    if (!template) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const { args: templateArgs, slotEntries } = resolveTemplateLayout(template);
    const cells = this.#cellsFor(templateArgs, slotEntries);
    const content = this.#contentChildren(located.entry);
    // More content than the template can hold: refuse before mutating.
    if (content.length > cells.length) {
      return false;
    }
    return this.wireframeMutationEngine.recordStructural(
      [located.outletName],
      () => {
        const layout = this.wireframeLayoutQuery.readResolvedLayout(
          located.outletName
        );
        if (!layout) {
          return false;
        }
        const result = replaceEntryInPlace(layout, gridKey, {
          ...located.entry,
          // Drop any resized `columnFractions` — the new shape defines its
          // own (even) tracks.
          args: { ...located.entry.args, ...templateArgs, columnFractions: [] },
          children: this.#reflowIntoCells(content, cells),
        });
        if (!result.changed) {
          return false;
        }
        this.wireframeMutationEngine.publishStructuralChange(
          located.outletName,
          result.layout
        );
        return true;
      }
    );
  }

  /**
   * Returns `true` when `applyGridTemplate` would succeed for the given
   * template against the currently-selected `wf:layout` — i.e. the
   * layout's content fits the template's number of cells. Pure-read;
   * the inspector calls this to disable a template option that can't
   * hold the current content. Mirrors the refusal predicate inside
   * `applyGridTemplate`.
   *
   * @param {{gridKey: string, template: Object}} args
   * @returns {boolean}
   */
  canApplyGridTemplate({ gridKey, template }) {
    if (!template) {
      return false;
    }
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(gridKey);
    if (!located) {
      return false;
    }
    const { args: templateArgs, slotEntries } = resolveTemplateLayout(template);
    const cells = this.#cellsFor(templateArgs, slotEntries);
    return this.#contentChildren(located.entry).length <= cells.length;
  }

  /**
   * Clamps every slot in a grid layout so its placement fits inside
   * the given bounds. Slots whose end lines exceed the new max get
   * their spans truncated; slots whose start lines exceed it get
   * snapped back to the last valid cell with span 1.
   *
   * Runs as a single structural-undo entry so the whole clamp can be
   * reverted with one Cmd+Z (e.g. after a "Reduce columns" confirm).
   *
   * @param {{gridKey: string, maxColumns: number, maxRows: number}} args
   * @returns {boolean}
   */
  clampGridSlotPlacements({ gridKey, maxColumns, maxRows }) {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(gridKey);
    if (!located || !this.wireframeLayoutQuery.isGridContainer(located.entry)) {
      return false;
    }
    const offenders = this.outOfBoundsSlotsIn(gridKey, maxColumns, maxRows);
    if (offenders.length === 0) {
      return false;
    }
    return this.wireframeMutationEngine.recordStructural(
      [located.outletName],
      () => {
        for (const slot of located.entry.children ?? []) {
          if (!this.wireframeLayoutQuery.isGridCellEntry(slot)) {
            continue;
          }
          const placement = parsePlacement(slot.containerArgs);
          const newColumn = this.#clampTrack(placement.column, maxColumns);
          const newRow = this.#clampTrack(placement.row, maxRows);
          if (newColumn == null && newRow == null) {
            continue;
          }
          const layout = this.wireframeLayoutQuery.readResolvedLayout(
            located.outletName
          );
          const result = replaceEntryContainerArgs(
            layout,
            entryKey(slot),
            "grid",
            (current) => ({
              ...current,
              ...(newColumn != null && { column: newColumn }),
              ...(newRow != null && { row: newRow }),
            })
          );
          if (!result.changed) {
            continue;
          }
          this.wireframeMutationEngine.publishStructuralChange(
            located.outletName,
            result.layout
          );
        }
        return true;
      }
    );
  }

  /**
   * The effective `{columns, rows}` of a grid layout — the larger of its
   * declared args and what its children occupy (see core's
   * `gridDimensions`). The inspector reads this for its column / row
   * fields and for shape-matching, so the displayed size always matches
   * the rendered grid rather than a bare default that can drift.
   *
   * @param {string} gridKey
   * @returns {{columns: number, rows: number}}
   */
  gridSizeFor(gridKey) {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(gridKey);
    const args = located?.entry.args ?? {};
    return gridDimensions(
      {
        columns: args.columns ?? DEFAULT_GRID_COLUMNS,
        rows: args.rows ?? DEFAULT_GRID_ROWS,
      },
      located?.entry.children
    );
  }

  /**
   * Returns the slot children of a grid `wf:layout` whose explicit
   * column / row placements would fall outside the given bounds. Each
   * entry yields the slot's composite key and the offending placement
   * for diagnostic / clamping callers.
   *
   * Auto-placed slots (no explicit column / row) are excluded — CSS
   * Grid auto-flow handles them regardless of the bounds change.
   *
   * @param {string} gridKey
   * @param {number} maxColumns
   * @param {number} maxRows
   * @returns {Array<{slotKey: string, column: string, row: string}>}
   */
  outOfBoundsSlotsIn(gridKey, maxColumns, maxRows) {
    const located = this.wireframeLayoutQuery.findEntryAndOutletSync(gridKey);
    if (!located || !this.wireframeLayoutQuery.isGridContainer(located.entry)) {
      return [];
    }
    const offenders = [];
    for (const slot of located.entry.children ?? []) {
      if (!this.wireframeLayoutQuery.isGridCellEntry(slot)) {
        continue;
      }
      const placement = parsePlacement(slot.containerArgs);
      const colExceeds =
        placement.column.start != null &&
        placement.column.end != null &&
        placement.column.end > maxColumns + 1;
      const rowExceeds =
        placement.row.start != null &&
        placement.row.end != null &&
        placement.row.end > maxRows + 1;
      if (colExceeds || rowExceeds) {
        offenders.push({
          slotKey: entryKey(slot),
          column: slot.containerArgs?.grid?.column ?? "auto",
          row: slot.containerArgs?.grid?.row ?? "auto",
        });
      }
    }
    return offenders;
  }

  /**
   * The ordered list of target cells for a template's resolved args.
   * A template with declared areas hands back its rects; a frame-only
   * preset (no areas) fills every cell of its grid.
   *
   * @param {Object} templateArgs
   * @param {Array<Object>} slotEntries
   * @returns {Array<{column: string, row: string}>}
   */
  #cellsFor(templateArgs, slotEntries) {
    if (slotEntries.length > 0) {
      return slotEntries.map((entry) => ({
        column: entry.containerArgs.grid.column,
        row: entry.containerArgs.grid.row,
      }));
    }
    return cellsForFree(templateArgs.columns ?? 3, templateArgs.rows ?? 1);
  }

  /**
   * Returns a clamped CSS Grid track shorthand, or `null` if the track
   * is already within bounds (so callers can skip writing it). Auto
   * placements pass through unchanged.
   *
   * @param {{start: number|null, end: number|null}} track
   * @param {number} max
   * @returns {string|null}
   */
  #clampTrack(track, max) {
    if (track.start == null) {
      return null;
    }
    const lastLine = max + 1;
    const start = Math.min(track.start, max);
    const end = track.end == null ? start + 1 : Math.min(track.end, lastLine);
    const safeEnd = Math.max(end, start + 1);
    if (start === track.start && safeEnd === track.end) {
      return null;
    }
    return safeEnd <= start + 1 ? `${start}` : `${start} / ${safeEnd}`;
  }

  /**
   * The layout entry's content children — everything except the empty
   * merged-cell placeholders, which are regenerated by the reflow rather
   * than carried across.
   *
   * @param {Object} entry
   * @returns {Array<Object>}
   */
  #contentChildren(entry) {
    return contentCells(entry.children);
  }

  /**
   * Reflows `content` into `cells`, with a container-validity guard: a
   * grid must have at least one child, but the reflow leaves single
   * empty cells derived (no entry). When the result would be empty (no
   * content and only single cells), materialise every cell as an empty
   * merged cell so the grid keeps a body and shows its shape.
   *
   * @param {Array<Object>} content
   * @param {Array<{column: string, row: string}>} cells
   * @returns {Array<Object>}
   */
  #reflowIntoCells(content, cells) {
    const reflowed = reflowChildrenIntoCells(content, cells);
    if (reflowed && reflowed.length > 0) {
      return reflowed;
    }
    return cells.map((cell) => ({
      block: LAYOUT_MERGED_CELL_BLOCK,
      containerArgs: {
        grid: {
          column: cell.column,
          row: cell.row,
          align: "stretch",
          justify: "stretch",
        },
      },
    }));
  }
}
