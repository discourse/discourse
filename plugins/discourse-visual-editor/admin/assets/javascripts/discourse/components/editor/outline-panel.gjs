// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trackedSet } from "@ember/reactive/collections";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";
import { walkAllOutlets } from "../../lib/walk-layout";

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

/**
 * Read-only outline of registered block outlet layouts. Renders one section
 * per outlet, each containing a flattened tree of its blocks. Clicking a row
 * mirrors the canvas: it sets the selected block in the editor service so the
 * inspector populates and the matching block on the canvas highlights.
 *
 * Phase 1 limitation: the underlying layout map is only exposed in DEBUG
 * builds (`_getOutletLayouts`). In production, the outline shows an empty
 * state. Phase 3 replaces the data source with a public API on
 * `services/blocks` once the layout resolution chain lands in core.
 */
export default class OutlinePanel extends Component {
  @service blocks;
  @service visualEditor;

  @tracked outlets = [];
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
  acceptedDragKinds = ["ve-block", "ve-palette-block"];
  isViewMode = (mode) => this.viewMode === mode;
  isStatusFilter = (filter) => this.statusFilter === filter;
  isRowCollapsed = (blockKey) => this.#collapsedKeys.has(blockKey);
  isOutletCollapsed = (outletName) => this.#collapsedOutlets.has(outletName);

  /**
   * `blockKey`s of container rows the user has collapsed in this
   * session. Rows whose ancestor chain includes a collapsed key are
   * filtered out of `decoratedGroups`. Session-only — collapse state
   * resets on editor exit, mirroring how transient UI state lives.
   */
  #collapsedKeys = trackedSet();

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

  @action
  async refresh() {
    this.outlets = await walkAllOutlets({
      blocksService: this.blocks,
      // Keep outlets the editor has touched even when their boundary
      // div is briefly absent from the DOM. After a publish the
      // `<BlockOutlet>` runs through `DAsyncContent`'s `:loading`
      // block (which renders nothing) before settling on the new
      // layout, so the mounted-outlet filter alone would flicker
      // edited rows out of the outline on every structural change.
      alwaysInclude: this.visualEditor._draftedOutlets,
    });
  }

  /**
   * Re-walks the outlets whenever a structural mutation lands. Reads the
   * service's monotonically-bumped `structuralVersion` so every move
   * triggers a fresh walk — `_structurallyEditedOutlets.size` would only
   * fire the first time an outlet is touched per session.
   *
   * The signal value itself is unused — the dependency is what matters.
   */
  get structuralVersion() {
    return this.visualEditor.structuralVersion;
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
      return { outletName: group.outletName, rows };
    });
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
    if (this.#collapsedKeys.size === 0) {
      return rows;
    }
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
        if (row.hasChildren && this.#collapsedKeys.has(row.blockKey)) {
          collapsedAncestors.push({ depth: row.depth, key: row.blockKey });
        }
        continue;
      }
      result.push(row);
      if (row.hasChildren && this.#collapsedKeys.has(row.blockKey)) {
        collapsedAncestors.push({ depth: row.depth, key: row.blockKey });
      }
    }
    return result;
  }

  /**
   * Toggles the collapse state for a container row. No-op for leaves.
   *
   * @param {Object} row
   * @param {Event} event - Click event; we stop propagation so the
   *   surrounding row's selection click doesn't also fire.
   */
  @action
  toggleCollapse(row, event) {
    event.stopPropagation();
    if (!row.hasChildren) {
      return;
    }
    if (this.#collapsedKeys.has(row.blockKey)) {
      this.#collapsedKeys.delete(row.blockKey);
    } else {
      this.#collapsedKeys.add(row.blockKey);
    }
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
    return {
      ...row,
      conditionPassing,
      conditionFailing,
      hasValidationError,
      hasError,
      isMuted,
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
      return i18n("visual_editor.outline.status.unknown_block");
    }
    if (row.validationFailure) {
      // The validator gives us a useful message string; surface it as
      // the tooltip so the author sees the specific problem without
      // having to open the inspector / read the console.
      return (
        row.validationReason ??
        i18n("visual_editor.outline.status.validation_failed")
      );
    }
    if (conditionFailing) {
      return i18n("visual_editor.outline.status.condition_failed");
    }
    if (row.hasConditions) {
      return i18n("visual_editor.outline.status.conditions_passing");
    }
    return null;
  }

  /**
   * @param {string} outletName - The owning outlet's name (the row itself
   *   does not carry it; we read it from the outer group when the user
   *   clicks).
   * @param {Object} row - A row produced by `walkAllOutlets`.
   */
  @action
  selectRow(outletName, row) {
    this.visualEditor.selectBlock({
      key: row.blockKey,
      name: row.blockName,
      id: row.blockId,
      args: row.args,
      conditions: row.conditions,
      outletName,
      metadata: this.lookupMetadataFor(row.blockName),
    });
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
    this.visualEditor.startDrag(source.data);
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
    const { source } = target;
    if (source?.type === "ve-palette-block") {
      this.visualEditor.insertBlock({
        blockName: source.data.blockName,
        defaultArgs: source.data.defaultArgs,
        targetKey: row.blockKey,
        position: "before",
        targetOutletName: outletName,
      });
    } else {
      this.visualEditor.moveBlock({
        sourceKey: source.data.blockKey,
        targetKey: row.blockKey,
        position: "before",
        targetOutletName: outletName,
      });
    }
    this.visualEditor.endDrag();
  }

  @action
  isRowDragSource(blockKey) {
    return this.visualEditor.dragSourceKey === blockKey;
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
      `.visual-editor-outlet-boundary[data-outlet-name="${outletName}"]`
    );
    if (el) {
      el.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  }

  <template>
    <div
      class="visual-editor-outline"
      {{didInsert this.refresh}}
      {{didUpdate
        this.refresh
        this.visualEditor.isActive
        this.structuralVersion
      }}
    >
      <div class="visual-editor-outline__view-switch" role="tablist">
        <button
          type="button"
          class={{dConcatClass
            "visual-editor-outline__view-tab"
            (if (this.isViewMode "tree") "--active")
          }}
          {{on "click" (fn this.setViewMode "tree")}}
        >
          {{i18n "visual_editor.outline.view_tree"}}
        </button>
        <button
          type="button"
          class={{dConcatClass
            "visual-editor-outline__view-tab"
            (if (this.isViewMode "outlets") "--active")
          }}
          {{on "click" (fn this.setViewMode "outlets")}}
        >
          {{i18n "visual_editor.outline.view_outlets"}}
        </button>
      </div>

      {{#if (this.isViewMode "tree")}}
        <div class="visual-editor-outline__filter-bar">
          <div class="visual-editor-outline__search">
            {{dIcon "magnifying-glass"}}
            <input
              type="search"
              value={{this.query}}
              placeholder={{i18n "visual_editor.outline.filter.placeholder"}}
              spellcheck="false"
              autocomplete="off"
              aria-label={{i18n "visual_editor.outline.filter.placeholder"}}
              {{on "input" this.onQueryInput}}
            />
            {{#if this.query}}
              <button
                type="button"
                class="visual-editor-outline__search-clear"
                aria-label={{i18n "visual_editor.outline.filter.clear"}}
                {{on "click" this.clearQuery}}
              >
                {{dIcon "xmark"}}
              </button>
            {{/if}}
          </div>
          <div class="visual-editor-outline__chips" role="tablist">
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-outline__chip"
                (if (this.isStatusFilter "all") "--active")
              }}
              {{on "click" (fn this.setStatusFilter "all")}}
            >
              {{i18n "visual_editor.outline.filter.chip_all"}}
            </button>
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-outline__chip"
                (if (this.isStatusFilter "errors") "--active")
              }}
              {{on "click" (fn this.setStatusFilter "errors")}}
            >
              {{dIcon "triangle-exclamation"}}
              {{i18n "visual_editor.outline.filter.chip_errors"}}
            </button>
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-outline__chip"
                (if (this.isStatusFilter "conditions") "--active")
              }}
              {{on "click" (fn this.setStatusFilter "conditions")}}
            >
              {{dIcon "filter"}}
              {{i18n "visual_editor.outline.filter.chip_conditions"}}
            </button>
          </div>
        </div>
      {{/if}}

      {{#if (this.isViewMode "outlets")}}
        {{#if this.outletsWithMetadata.length}}
          <div class="visual-editor-outline__outlets">
            {{#each this.outletsWithMetadata as |entry|}}
              <button
                type="button"
                class="visual-editor-outline__outlet-row"
                title={{entry.description}}
                {{on "click" (fn this.jumpToOutlet entry.name)}}
              >
                <span class="visual-editor-outline__outlet-name">
                  {{dIcon "cubes"}}
                  <span>{{entry.displayName}}</span>
                </span>
                <span class="visual-editor-outline__outlet-meta">
                  {{entry.name}}
                  ·
                  {{i18n
                    "visual_editor.outlets.block_count"
                    count=entry.blockCount
                  }}
                </span>
              </button>
            {{/each}}
          </div>
        {{else}}
          <div class="panel-empty">{{i18n "visual_editor.outline.empty"}}</div>
        {{/if}}
      {{else if this.decoratedGroups.length}}
        {{#each this.decoratedGroups as |group|}}
          <div class="outline-outlet">
            <button
              type="button"
              class="outline-outlet__label"
              aria-expanded={{if
                (this.isOutletCollapsed group.outletName)
                "false"
                "true"
              }}
              {{on "click" (fn this.toggleOutlet group.outletName)}}
            >
              {{dIcon
                (if
                  (this.isOutletCollapsed group.outletName)
                  "chevron-right"
                  "chevron-down"
                )
              }}
              {{dIcon "cubes"}}
              <span>{{group.outletName}}</span>
            </button>
            {{#unless (this.isOutletCollapsed group.outletName)}}
              {{#each group.rows as |row|}}
                <div
                  class={{dConcatClass
                    "outline-block"
                    (if
                      (this.visualEditor.isBlockSelected row.blockKey)
                      "--selected"
                    )
                    (if (this.isRowDragSource row.blockKey) "--dragging")
                    (if row.hasError "--error")
                    (if row.isMuted "--muted")
                  }}
                  role="button"
                  tabindex="0"
                  style={{rowPadding row.depth}}
                  {{on "click" (fn this.selectRow group.outletName row)}}
                  {{dDragAndDropSource
                    type="ve-block"
                    data=(hash
                      blockKey=row.blockKey outletName=group.outletName
                    )
                    onDragStart=this.handleRowDragStart
                    onDrop=this.visualEditor.endDrag
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
                    {{! template-lint-disable no-nested-interactive }}
                    <button
                      type="button"
                      class="outline-block__toggle"
                      aria-label={{i18n
                        (if
                          (this.isRowCollapsed row.blockKey)
                          "visual_editor.outline.expand_row"
                          "visual_editor.outline.collapse_row"
                        )
                      }}
                      {{on "click" (fn this.toggleCollapse row)}}
                    >
                      {{dIcon
                        (if
                          (this.isRowCollapsed row.blockKey)
                          "chevron-right"
                          "chevron-down"
                        )
                      }}
                    </button>
                  {{else}}
                    <span class="outline-block__leaf">{{dIcon "cube"}}</span>
                  {{/if}}
                  <span class="outline-block__name">{{row.blockName}}</span>
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
        <div class="panel-empty">{{i18n "visual_editor.outline.empty"}}</div>
      {{/if}}
    </div>
  </template>
}
