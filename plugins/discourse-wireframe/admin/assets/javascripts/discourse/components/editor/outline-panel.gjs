// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedMap, trackedSet } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { TrackedAsyncData } from "ember-async-data";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { normalizeLayoutMode, walkAllOutlets } from "../../lib/walk-layout";

// Inline `padding-left` driven by tree depth. We use `trustHTML` because
// the value is a constant we compute (no user input), and Ember will
// otherwise warn about dynamic style bindings.
//
// The base 1rem offset indents every row at least one level under the
// outlet label, so the hierarchy (outlet → its blocks) reads as a
// nested tree instead of a flat list flush with the outlet heading.
function rowPadding(depth) {
  return trustHTML(`padding-left: ${1 + depth * 0.75}rem;`);
}

// A container with more than this many children starts collapsed in the
// outline (showing a "× N" count badge) so a large layout — a 12-card grid, a
// long carousel — stays scannable instead of flooding the tree. The user can
// still expand it; their explicit choice overrides this default.
const CHILD_COUNT_THRESHOLD = 6;

/**
 * Read-only outline of registered block outlet layouts. Renders one section
 * per outlet, each containing a flattened tree of its blocks. Clicking a row
 * mirrors the canvas: it sets the selected block in the editor service so the
 * inspector populates and the matching block on the canvas highlights.
 */
export default class OutlinePanel extends Component {
  @service blocks;
  @service wireframe;
  @service wireframeBlockMutations;
  @service wireframeDragSession;
  @service wireframeEditEngine;
  @service wireframeRevision;
  @service wireframeSelection;
  @service wireframeSession;

  /** "tree" — flat per-block view (default); "outlets" — per-outlet summary. */
  @tracked viewMode = "tree";

  /**
   * Free-text query that filters tree rows by block name / id (case-
   * insensitive substring). Empty string disables the filter.
   */
  @tracked query = "";

  /**
   * Status filter chip. `"all"` shows every row, `"errors"` shows rows
   * with any failure status (unknown block, condition failing), and
   * `"conditions"` shows rows that have conditions at all. Single-select.
   */
  @tracked statusFilter = "all";
  acceptedDragKinds = ["wf-block", "wf-palette-block"];
  isViewMode = (mode) => this.viewMode === mode;
  isStatusFilter = (filter) => this.statusFilter === filter;
  /**
   * Whether a container row is collapsed. A row the user has explicitly toggled
   * uses that choice; otherwise it falls back to the default — collapsed when
   * the child count exceeds the threshold, expanded below it.
   *
   * @param {Object} row - The outline row (needs `blockKey` + `childCount`).
   * @returns {boolean}
   */
  isRowCollapsed = (row) =>
    this.#collapseOverrides.has(row.blockKey)
      ? this.#collapseOverrides.get(row.blockKey)
      : row.childCount > CHILD_COUNT_THRESHOLD;
  isOutletCollapsed = (outletName) => this.#collapsedOutlets.has(outletName);

  /**
   * Whether `rootKey` is the current selection — drives the outlet header's
   * selected styling.
   *
   * @param {string|null} rootKey
   * @returns {boolean}
   */
  isOutletSelected = (rootKey) => {
    return rootKey != null && this.wireframeSelection.isBlockSelected(rootKey);
  };
  /**
   * Explicit per-row collapse choices keyed by `blockKey` (`true` = collapsed,
   * `false` = expanded). Only rows the user has toggled appear here; everything
   * else uses the threshold default in `isRowCollapsed`. Rows whose ancestor
   * chain resolves to collapsed are filtered out of `decoratedGroups`.
   * Session-only — resets on editor exit, mirroring how transient UI state lives.
   */
  #collapseOverrides = trackedMap();

  /**
   * Outlet names the user has collapsed in the tree view. When an
   * outlet is collapsed the group header still renders (so the user
   * can expand it again) but its row list is suppressed.
   */
  #collapsedOutlets = trackedSet();

  /**
   * Lazy `blockName -> metadata` index built on first row selection.
   * Each row in the outline maps to a single block class; caching the
   * whole registry up-front would walk every block on first render
   * even for outlets the author never opens, so we build it on demand.
   */
  #metaIndex = null;

  /**
   * Wraps the async outlet walk in `TrackedAsyncData` so the template
   * can read `.value` without juggling a `@tracked outlets` field and
   * a `didUpdate`-driven `refresh()`. Recomputes when:
   *
   *   - `wireframeSession.active` flips (editor opens / closes)
   *   - `wireframeRevision.version` bumps (structural mutation lands; the layer
   *     is republished and validation re-runs against the fresh entries)
   *   - any entry's soft-failure stamp changes — `walkAllOutlets`'s sync
   *     prefix touches `__failureType` / `__failureReason` on every
   *     entry before its first `await`, so the per-key tag deps on the
   *     trackedObject-wrapped entries attach to this getter's tracking
   *     frame. `clearValidatorStamps` then propagates straight through.
   *
   * `alwaysInclude` keeps outlets the editor has touched in the walk
   * even when their boundary div briefly leaves the DOM between
   * publish and re-render (DAsyncContent's `:loading` block paints
   * nothing in the gap).
   */
  @cached
  get outletsData() {
    void this.wireframeSession.active;
    void this.wireframeRevision.version;
    return new TrackedAsyncData(
      walkAllOutlets({
        blocksService: this.blocks,
        alwaysInclude: new Set(this.wireframeEditEngine.draftedOutletNames()),
      })
    );
  }

  /**
   * Resolved walk result (or an empty list while the first walk is
   * still pending). Downstream getters key off this rather than the
   * full `TrackedAsyncData` shape — they don't need the loading state.
   *
   * `TrackedAsyncData#value` throws unless `.isResolved` — guard
   * explicitly so the first render (before the walk's promise has
   * settled) returns `[]` instead of crashing.
   */
  get outlets() {
    return this.outletsData.isResolved ? this.outletsData.value : [];
  }

  /**
   * Decorated rows grouped by outlet. Joins the raw walker output with
   * derived per-row status (condition pass/fail, unknown-block) so the
   * template can render the right icon without computing anything inline.
   *
   * `@cached` keeps this stable across renders — it only recomputes when
   * one of its tracked reads (`this.outlets`, query / filter, sim state
   * via `evaluate`) changes.
   *
   * @returns {Array<{outletName: string, rows: Array<Object>}>}
   */
  @cached
  get decoratedGroups() {
    const q = this.query.trim().toLowerCase();
    const status = this.statusFilter;
    return this.outlets.map((group) => {
      const decorated = group.rows.map((row) => this.#decorateRow(row));
      const visible = this.#dropCollapsedDescendants(decorated);
      const rows = visible.filter((row) =>
        this.#matchesFilters(row, q, status)
      );
      return {
        outletName: group.outletName,
        rows,
        rootKey: group.rootKey,
        mode: group.mode,
      };
    });
  }

  /**
   * Decorated per-outlet entries for the "Outlets" view mode — joins
   * `walkAllOutlets`'s row counts with `listOutletsWithMetadata()`
   * display info. Mounted-outlet filtering already happens inside
   * `walkAllOutlets`, so any outlet here is on the current page.
   */
  get outletsWithMetadata() {
    const meta = new Map(
      this.blocks.listOutletsWithMetadata().map((entry) => [entry.name, entry])
    );
    return this.outlets.map((group) => {
      const m = meta.get(group.outletName);
      return {
        name: group.outletName,
        displayName: m?.displayName ?? group.outletName,
        description: m?.description ?? null,
        blockCount: group.rows.length,
      };
    });
  }

  /**
   * Toggles the collapse state for a container row. No-op for leaves.
   *
   * DButton stops propagation of its own click, so the surrounding
   * row's selection handler does not also fire.
   *
   * @param {Object} row
   */
  @action
  toggleCollapse(row) {
    if (!row.hasChildren) {
      return;
    }
    // Record the flipped state as an explicit override so it sticks against the
    // threshold default (a big container the user expanded stays expanded).
    this.#collapseOverrides.set(row.blockKey, !this.isRowCollapsed(row));
  }

  /**
   * Toggles the collapse state for an outlet group header. Hides the
   * outlet's rows in the tree view while keeping its label visible
   * so the user can re-expand.
   *
   * @param {string} outletName
   */
  @action
  toggleOutlet(outletName) {
    if (this.#collapsedOutlets.has(outletName)) {
      this.#collapsedOutlets.delete(outletName);
    } else {
      this.#collapsedOutlets.add(outletName);
    }
  }

  /**
   * Selects the clicked row, honoring modifier keys to build a multi-selection:
   * cmd/ctrl-click toggles the row in/out of the selection, shift-click selects
   * the contiguous range from the current primary to the clicked row (within
   * the same outlet's visible rows), and a plain click selects just this row.
   *
   * @param {string} outletName - The owning outlet's name (the row itself
   *   does not carry it; we read it from the outer group when the user clicks).
   * @param {Object} row - A row produced by `walkAllOutlets`.
   * @param {MouseEvent} [event] - Appended by `{{on "click"}}`; carries the
   *   modifier-key state.
   */
  @action
  selectRow(outletName, row, event) {
    const data = this.#rowData(outletName, row);

    if (event?.metaKey || event?.ctrlKey) {
      this.wireframeSelection.toggleBlockSelection(data);
    } else if (event?.shiftKey) {
      const keys = this.#rangeKeys(outletName, row);
      if (keys) {
        this.wireframeSelection.setSelectionRange(keys, data);
      } else {
        this.wireframeSelection.selectBlock(data);
      }
    } else {
      this.wireframeSelection.selectBlock(data);
    }

    // Flash the block on the canvas so the eye lands on it after it scrolls
    // into view — the outline row is far from the rendered block.
    this.wireframe.flashBlock(row.blockKey);
  }

  /**
   * Builds the selection payload for a row (the shape `selectBlock` and the
   * multi-select gestures expect).
   *
   * @param {string} outletName
   * @param {Object} row
   * @returns {Object}
   */
  #rowData(outletName, row) {
    return {
      key: row.blockKey,
      name: row.blockName,
      id: row.blockId,
      args: row.args,
      conditions: row.conditions,
      outletName,
      metadata: this.lookupMetadataFor(row.blockName),
    };
  }

  /**
   * The block keys spanning the current primary selection and `toRow`, within
   * the clicked outlet's visible rows — the shift-click range. Returns `null`
   * when there's no anchor or either endpoint isn't a visible row (e.g. the
   * anchor is in another outlet or hidden under a collapsed container), so the
   * caller falls back to a plain single select.
   *
   * @param {string} outletName
   * @param {Object} toRow
   * @returns {Array<string>|null}
   */
  #rangeKeys(outletName, toRow) {
    const anchorKey = this.wireframeSelection.selectedBlockKey;
    if (!anchorKey) {
      return null;
    }
    const group = this.decoratedGroups.find((g) => g.outletName === outletName);
    const rows = group?.rows ?? [];
    const anchorIndex = rows.findIndex((r) => r.blockKey === anchorKey);
    const toIndex = rows.findIndex((r) => r.blockKey === toRow.blockKey);
    if (anchorIndex === -1 || toIndex === -1) {
      return null;
    }
    const [lo, hi] =
      anchorIndex <= toIndex ? [anchorIndex, toIndex] : [toIndex, anchorIndex];
    return rows.slice(lo, hi + 1).map((r) => r.blockKey);
  }

  /**
   * Selects an outlet by selecting its implicit root layout — the outline
   * header acts as the outlet's selection target, surfacing the layout form.
   *
   * @param {string} outletName
   */
  @action
  selectOutletRoot(outletName) {
    this.wireframeSelection.selectOutlet(outletName);
  }

  lookupMetadataFor(blockName) {
    if (!this.#metaIndex) {
      this.#metaIndex = new Map(
        this.blocks
          .listBlocksWithMetadata()
          .map(({ name, metadata }) => [name, metadata])
      );
    }
    return this.#metaIndex.get(blockName) ?? null;
  }

  /**
   * Adapts the source modifier's `{source}` payload into the flat
   * `{blockKey, outletName}` argument the editor service expects.
   * The data was attached at the `dDragAndDropSource` call site as
   * `(hash blockKey=… outletName=…)` and exposed back under
   * `source.data`.
   */
  @action
  handleRowDragStart({ source }) {
    // Synthesized composite parts aren't reorderable — never start a drag for
    // one. (The underlying move would no-op anyway, but this avoids the
    // misleading drag affordance.)
    if (source?.data?.isPart) {
      return;
    }
    this.wireframe.startDrag(source.data);
  }

  /**
   * Drop-target for an outline row. Maps every drop into a `before`
   * action — the outline is a flat ordered list, so "drop on row X"
   * reads as "place above row X". Branches on `source.type` to support
   * both moves (existing block dragged within the tree) and inserts
   * (palette block dropped onto an outline row).
   *
   * @param {string} outletName
   * @param {Object} row - Row produced by `walkAllOutlets`.
   * @param {{ source: { type: string, data: Object } }} target
   */
  @action
  applyRowDrop(outletName, row, target) {
    // A synthesized composite part isn't a real layout position — dropping
    // onto/around it can't move or insert anything, so ignore the drop.
    if (row.isPart) {
      this.wireframe.endDrag();
      return;
    }
    const { source } = target;
    if (source?.type === "wf-palette-block") {
      this.wireframeBlockMutations.insertBlock({
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        targetKey: row.blockKey,
        position: "before",
        targetOutletName: outletName,
      });
    } else {
      this.wireframeBlockMutations.moveBlock({
        sourceKey: source.data.blockKey,
        targetKey: row.blockKey,
        position: "before",
        targetOutletName: outletName,
      });
    }
    this.wireframe.endDrag();
  }

  @action
  isRowDragSource(blockKey) {
    return this.wireframeDragSession.sourceKey === blockKey;
  }

  @action
  setViewMode(mode) {
    this.viewMode = mode;
  }

  @action
  setStatusFilter(filter) {
    this.statusFilter = filter;
  }

  @action
  onQueryInput(event) {
    this.query = event.target.value;
  }

  @action
  clearQuery() {
    this.query = "";
  }

  @action
  jumpToOutlet(outletName) {
    const el = document.querySelector(
      `.wireframe-outlet-boundary[data-outlet-name="${outletName}"]`
    );
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  /**
   * Walks the DFS-ordered row list and drops every row whose ancestor
   * chain includes a collapsed `blockKey`. Uses the depth field on
   * each row to track the active ancestor stack — when we re-enter a
   * shallower depth, the deeper ancestors are popped automatically.
   *
   * @param {Array<Object>} rows - DFS-ordered, depth-aware rows.
   * @returns {Array<Object>}
   */
  #dropCollapsedDescendants(rows) {
    /** @type {Array<{depth: number, key: string}>} */
    const collapsedAncestors = [];
    const result = [];
    for (const row of rows) {
      while (
        collapsedAncestors.length > 0 &&
        collapsedAncestors[collapsedAncestors.length - 1].depth >= row.depth
      ) {
        collapsedAncestors.pop();
      }
      if (collapsedAncestors.length > 0) {
        // Suppressed by a collapsed ancestor — skip but still consider
        // whether this row itself is also collapsed (so its own
        // descendants stay suppressed even if a deeper grandparent
        // expands later).
        if (row.hasChildren && this.isRowCollapsed(row)) {
          collapsedAncestors.push({ depth: row.depth, key: row.blockKey });
        }
        continue;
      }
      result.push(row);
      if (row.hasChildren && this.isRowCollapsed(row)) {
        collapsedAncestors.push({ depth: row.depth, key: row.blockKey });
      }
    }
    return result;
  }

  /**
   * Returns true when the row passes both the text search and status
   * chip. Hidden behind the filter pipeline so the template stays free
   * of conditional logic.
   *
   * @param {Object} row
   * @param {string} normalizedQuery - Already lowercased / trimmed.
   * @param {string} status - One of "all" | "errors" | "conditions".
   */
  #matchesFilters(row, normalizedQuery, status) {
    if (normalizedQuery) {
      const name = row.blockName?.toLowerCase() ?? "";
      const id = row.blockId?.toLowerCase() ?? "";
      if (!name.includes(normalizedQuery) && !id.includes(normalizedQuery)) {
        return false;
      }
    }
    if (status === "errors") {
      return row.hasError;
    }
    if (status === "conditions") {
      return row.hasConditions;
    }
    return true;
  }

  /**
   * Adds per-row status flags used by the template. Resolves the row's
   * condition spec against the blocks service so a passing-but-gated
   * block (lock icon) is distinguishable from a failing one (eye-slash).
   *
   * Wrapped in try/catch because condition specs can throw on malformed
   * input (the resolver leaves a `__failureType` behind for those, but
   * the walker exposes the raw spec — same data, different surface);
   * treating a throw as "condition failed" keeps the outline readable
   * either way.
   *
   * @param {Object} row
   */
  #decorateRow(row) {
    let conditionPassing = true;
    if (row.hasConditions) {
      try {
        conditionPassing = !!this.blocks.evaluate(row.conditions);
      } catch {
        conditionPassing = false;
      }
    }
    const conditionFailing = row.hasConditions && !conditionPassing;
    // `validationFailure` carries soft-failures from the layout validator
    // (e.g. an empty container, args mismatch). Treat them as errors
    // alongside unknown blocks — both are author-facing problems.
    const hasValidationError = !!row.validationFailure;
    // `hasError` mirrors the canvas ghost's `--error` modifier — danger-
    // tone is reserved for genuine authoring mistakes (UNKNOWN_BLOCK,
    // structural-invalid). Condition-failed is intentional gating; it
    // shows the eye-slash icon but stays in neutral row colors so the
    // outline doesn't shout at the author about their own conditions.
    const hasError = row.isUnknown || hasValidationError;
    // `isMuted` matches the canvas ghost's faded silhouette: a block
    // that's hidden by its own conditions isn't an authoring mistake,
    // it's just not rendering right now. Dim the row so the outline
    // signals "won't show on the live page" without using error red.
    const isMuted = !hasError && conditionFailing;
    // Nested `layout` blocks carry the same `mode` arg as the outlet's
    // implicit root layout (stack / row / grid). Surface it as a chip on
    // the row so the structure reads at a glance — mirrors the mode chip
    // the outlet header shows for its root layout. Non-layout blocks get
    // `null` so the badge only renders where a mode is meaningful.
    const layoutMode =
      row.blockName === "layout" ? normalizeLayoutMode(row.args?.mode) : null;
    return {
      ...row,
      conditionPassing,
      conditionFailing,
      hasValidationError,
      hasError,
      isMuted,
      layoutMode,
      statusIcon: this.#statusIconFor(row, conditionFailing),
      statusTooltip: this.#statusTooltipFor(row, conditionFailing),
    };
  }

  /**
   * Picks the right icon name for the row's status badge.
   *   - Unknown block → triangle-exclamation.
   *   - Conditions present and failing → eye-slash.
   *   - Conditions present and passing → lock.
   *   - Otherwise → null (no badge).
   */
  #statusIconFor(row, conditionFailing) {
    if (row.isUnknown) {
      return "triangle-exclamation";
    }
    if (row.validationFailure) {
      // Structural-invalid (e.g. an empty container, malformed args)
      // shares the unknown-block treatment — both are authoring
      // problems that need the author's attention.
      return "triangle-exclamation";
    }
    if (conditionFailing) {
      return "eye-slash";
    }
    if (row.hasConditions) {
      return "filter";
    }
    return null;
  }

  #statusTooltipFor(row, conditionFailing) {
    if (row.isUnknown) {
      return i18n("wireframe.outline.status.unknown_block");
    }
    if (row.validationFailure) {
      // The validator gives us a useful message string; surface it as
      // the tooltip so the author sees the specific problem without
      // having to open the inspector / read the console.
      return (
        row.validationReason ??
        i18n("wireframe.outline.status.validation_failed")
      );
    }
    if (conditionFailing) {
      return i18n("wireframe.outline.status.condition_failed");
    }
    if (row.hasConditions) {
      return i18n("wireframe.outline.status.conditions_passing");
    }
    return null;
  }

  <template>
    <div class="wireframe-outline">
      <div class="wireframe-outline__view-switch" role="tablist">
        <DButton
          class={{dConcatClass
            "wireframe-outline__view-tab"
            (if (this.isViewMode "tree") "--active")
          }}
          @label="wireframe.outline.view_tree"
          @action={{fn this.setViewMode "tree"}}
        />
        <DButton
          class={{dConcatClass
            "wireframe-outline__view-tab"
            (if (this.isViewMode "outlets") "--active")
          }}
          @label="wireframe.outline.view_outlets"
          @action={{fn this.setViewMode "outlets"}}
        />
      </div>

      {{#if (this.isViewMode "tree")}}
        <div class="wireframe-outline__filter-bar">
          <div class="wireframe-outline__search">
            {{dIcon "magnifying-glass"}}
            <input
              type="search"
              value={{this.query}}
              placeholder={{i18n "wireframe.outline.filter.placeholder"}}
              spellcheck="false"
              autocomplete="off"
              aria-label={{i18n "wireframe.outline.filter.placeholder"}}
              {{on "input" this.onQueryInput}}
            />
            {{#if this.query}}
              <DButton
                class="wireframe-outline__search-clear"
                @icon="xmark"
                @ariaLabel="wireframe.outline.filter.clear"
                @action={{this.clearQuery}}
              />
            {{/if}}
          </div>
          <div class="wireframe-outline__chips" role="tablist">
            <DButton
              class={{dConcatClass
                "wireframe-outline__chip"
                (if (this.isStatusFilter "all") "--active")
              }}
              @label="wireframe.outline.filter.chip_all"
              @action={{fn this.setStatusFilter "all"}}
            />
            <DButton
              class={{dConcatClass
                "wireframe-outline__chip"
                (if (this.isStatusFilter "errors") "--active")
              }}
              @icon="triangle-exclamation"
              @label="wireframe.outline.filter.chip_errors"
              @action={{fn this.setStatusFilter "errors"}}
            />
            <DButton
              class={{dConcatClass
                "wireframe-outline__chip"
                (if (this.isStatusFilter "conditions") "--active")
              }}
              @icon="filter"
              @label="wireframe.outline.filter.chip_conditions"
              @action={{fn this.setStatusFilter "conditions"}}
            />
          </div>
        </div>
      {{/if}}

      {{#if (this.isViewMode "outlets")}}
        {{#if this.outletsWithMetadata.length}}
          <div class="wireframe-outline__outlets">
            {{#each this.outletsWithMetadata as |entry|}}
              <DButton
                class="wireframe-outline__outlet-row"
                @translatedTitle={{entry.description}}
                @action={{fn this.jumpToOutlet entry.name}}
              >
                <span class="wireframe-outline__outlet-name">
                  {{dIcon "cubes"}}
                  <span>{{entry.displayName}}</span>
                </span>
                <span class="wireframe-outline__outlet-meta">
                  {{entry.name}}
                  ·
                  {{i18n
                    "wireframe.outlets.block_count"
                    count=entry.blockCount
                  }}
                </span>
              </DButton>
            {{/each}}
          </div>
        {{else}}
          <div class="panel-empty">{{i18n "wireframe.outline.empty"}}</div>
        {{/if}}
      {{else if this.decoratedGroups.length}}
        {{#each this.decoratedGroups as |group|}}
          <div class="outline-outlet">
            {{! The header chevron toggles collapse; the label selects the
              outlet (its implicit root layout) so the inspector shows the
              layout form. Two distinct interactions, so two controls. }}
            <div
              class={{dConcatClass
                "outline-outlet__header"
                (if (this.isOutletSelected group.rootKey) "--selected")
              }}
            >
              <DButton
                class="outline-outlet__toggle"
                @ariaExpanded={{if
                  (this.isOutletCollapsed group.outletName)
                  false
                  true
                }}
                @icon={{if
                  (this.isOutletCollapsed group.outletName)
                  "chevron-right"
                  "chevron-down"
                }}
                @ariaLabel={{if
                  (this.isOutletCollapsed group.outletName)
                  "wireframe.outline.expand_row"
                  "wireframe.outline.collapse_row"
                }}
                @action={{fn this.toggleOutlet group.outletName}}
              />
              <DButton
                class="outline-outlet__label"
                @action={{fn this.selectOutletRoot group.outletName}}
              >
                {{dIcon "cubes"}}
                <span class="outline-outlet__name">{{group.outletName}}</span>
                {{#if group.mode}}
                  <span class="outline-outlet__mode">
                    {{i18n
                      (concat "wireframe.inspector.layout.mode_" group.mode)
                    }}
                  </span>
                {{/if}}
              </DButton>
            </div>
            {{#unless (this.isOutletCollapsed group.outletName)}}
              {{#each group.rows as |row|}}
                <div
                  class={{dConcatClass
                    "outline-block"
                    (if
                      (this.wireframeSelection.isBlockSelected row.blockKey)
                      "--selected"
                    )
                    (if (this.isRowDragSource row.blockKey) "--dragging")
                    (if row.hasError "--error")
                    (if row.isMuted "--muted")
                    (if row.isPart "--part")
                  }}
                  role="button"
                  tabindex="0"
                  style={{rowPadding row.depth}}
                  {{on "click" (fn this.selectRow group.outletName row)}}
                  {{dDragAndDropSource
                    type="wf-block"
                    data=(hash
                      blockKey=row.blockKey
                      outletName=group.outletName
                      isPart=row.isPart
                    )
                    onDragStart=this.handleRowDragStart
                    onDrop=this.wireframe.endDrag
                  }}
                  {{dDragAndDropTarget
                    accepts=this.acceptedDragKinds
                    position="before"
                    onDrop=(fn this.applyRowDrop group.outletName row)
                  }}
                >
                  {{! The chevron sits inside a row that's role="button"
                    for selection. stopPropagation on `toggleCollapse`
                    keeps the row click from firing alongside the
                    collapse toggle, so the two interactions are
                    logically distinct even though they nest. }}
                  {{#if row.hasChildren}}

                    <DButton
                      class="outline-block__toggle"
                      @icon={{if
                        (this.isRowCollapsed row)
                        "chevron-right"
                        "chevron-down"
                      }}
                      @ariaLabel={{if
                        (this.isRowCollapsed row)
                        "wireframe.outline.expand_row"
                        "wireframe.outline.collapse_row"
                      }}
                      @action={{fn this.toggleCollapse row}}
                    />
                  {{else}}
                    <span class="outline-block__leaf">
                      {{dIcon (if row.isPart "circle-dashed" "cube")}}
                    </span>
                  {{/if}}
                  {{! The block name is the row's primary text; a child of an
                      ordinal-naming container (a carousel slide, a tabs panel)
                      gets its position as a separate chip below, and its own
                      label as the row's hover tooltip. }}
                  <span class="outline-block__name" title={{row.childLabel}}>
                    {{row.blockName}}
                  </span>
                  {{#if (this.isRowCollapsed row)}}
                    {{! Count badge surfacing how many child rows are hidden
                      while the container is collapsed — the compaction cue for
                      large containers. }}
                    <span class="outline-block__child-count">
                      {{i18n
                        "wireframe.outline.child_count"
                        count=row.childCount
                      }}
                    </span>
                  {{/if}}
                  {{#if row.slideOrdinal}}
                    {{! A noun-framed container's child (a carousel slide, a tabs
                        panel) shows its 1-based position as a chip beside the
                        block name, ahead of the layout-mode chip. }}
                    <span class="outline-block__ordinal">
                      {{i18n row.slideNumberKey number=row.slideOrdinal}}
                    </span>
                  {{/if}}
                  {{#if row.layoutMode}}
                    <span class="outline-block__mode">
                      {{i18n
                        (concat
                          "wireframe.inspector.layout.mode_" row.layoutMode
                        )
                      }}
                    </span>
                  {{/if}}
                  {{#if row.blockId}}
                    <span class="outline-block__id">#{{row.blockId}}</span>
                  {{/if}}
                  {{#if row.statusIcon}}
                    <span
                      class="outline-block__status"
                      title={{row.statusTooltip}}
                      aria-label={{row.statusTooltip}}
                    >
                      {{dIcon row.statusIcon}}
                    </span>
                  {{/if}}
                </div>
              {{/each}}
            {{/unless}}
          </div>
        {{/each}}
      {{else}}
        <div class="panel-empty">{{i18n "wireframe.outline.empty"}}</div>
      {{/if}}
    </div>
  </template>
}
