// @ts-check
import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { GRID_TEMPLATES, parseGridAreas } from "../../lib/grid-templates";

/**
 * Custom inspector form for the `wf:layout` block. The generic
 * FormKit form would show a bag of fields (mode, columns,
 * gap, ...) where most aren't relevant for the current mode. This
 * form swaps in mode-specific controls and uses richer affordances
 * (segmented selectors, steppers, sliders) instead of bare inputs.
 *
 * Live updates flow through `wireframe.updateSelectedArg`, same
 * channel the generic form uses — the canvas reflects changes
 * without remounting the form.
 */
const MODES = [
  { id: "stack", labelKey: "mode_stack", icon: "arrow-down" },
  { id: "row", labelKey: "mode_row", icon: "arrow-right" },
  { id: "grid", labelKey: "mode_grid", icon: "table-cells-large" },
];

// Auto-collapse options for grid / row layouts. Each value maps to a
// `wf-layout--collapse-{id}` modifier class consumed by the
// `@container` rules in wireframe.scss. The labels live in i18n
// (`auto_collapse_{id}`); each option carries its own help-text key
// for the dynamic hint copy beneath the segmented selector.
const AUTO_COLLAPSE_OPTIONS = [
  { id: "never", labelKey: "auto_collapse_never" },
  { id: "compact", labelKey: "auto_collapse_compact" },
  { id: "default", labelKey: "auto_collapse_default" },
];

const ALIGNMENTS = ["start", "center", "end", "stretch"];

const COLUMNS_MIN = 1;
const COLUMNS_MAX = 12;
const ROWS_MIN = 1;
const ROWS_MAX = 8;
const GAP_MIN = 0;
const GAP_MAX = 4;
const GAP_STEP = 0.25;

export default class InspectorLayoutForm extends Component {
  @service wireframe;
  @service dialog;

  /**
   * Predicate the template-chip render uses to grey out templates
   * that can't fit the current layout (a template with fewer slots
   * than there are existing children). Delegates to the service so
   * the refusal logic lives next to `applyGridTemplate` and the two
   * stay in lockstep.
   */
  canApplyTemplate = (template) => {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return false;
    }
    return this.wireframe.canApplyGridTemplate({
      gridKey: data.key,
      template,
    });
  };

  /**
   * Slot keys whose placements fall OUTSIDE the current grid's
   * `columns` × `rows` bounds. Surfaces as a warning inside the form
   * so authors can spot a layout that loaded with bad data (e.g.
   * saved at 6 columns, schema later reduced to 3). The user fixes
   * by either bumping columns/rows back up, or by clicking the
   * "clamp" button which routes through the service helper.
   *
   * @returns {Array<{slotKey: string, column: string, row: string}>}
   */
  get outOfBoundsSlots() {
    if (!this.isGrid) {
      return [];
    }
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return [];
    }
    return this.wireframe.outOfBoundsSlotsIn(data.key, this.columns, this.rows);
  }

  get hasOutOfBoundsSlots() {
    return this.outOfBoundsSlots.length > 0;
  }

  get args_() {
    return this.wireframe.selectedBlockData?.args ?? {};
  }

  get mode() {
    // Coerce the legacy `"free-grid"` mode value to `"grid"` so the
    // segmented control highlights the right segment and the rest of
    // the form behaves consistently with the new naming.
    const raw = this.args_.mode ?? "stack";
    return raw === "free-grid" ? "grid" : raw;
  }

  get isGrid() {
    return this.mode === "grid";
  }

  get columns() {
    return this.args_.columns ?? 6;
  }

  get rows() {
    return this.args_.rows ?? 2;
  }

  get gap() {
    return this.args_.gap ?? 1;
  }

  get align() {
    return this.args_.align ?? "stretch";
  }

  get columnTemplate() {
    return this.args_.columnTemplate ?? "";
  }

  get rowTemplate() {
    return this.args_.rowTemplate ?? "";
  }

  get autoCollapse() {
    return this.args_.autoCollapse ?? "default";
  }

  /**
   * i18n key for the dynamic help text beneath the auto-collapse
   * segmented selector. Keys follow the `auto_collapse_help_{value}`
   * pattern — one per enum value.
   */
  get autoCollapseHelpKey() {
    return `wireframe.inspector.layout.auto_collapse_help_${this.autoCollapse}`;
  }

  set(name, value) {
    this.wireframe.updateSelectedArg(name, value);
  }

  @action
  setMode(mode) {
    this.set("mode", mode);
  }

  @action
  setAutoCollapse(value) {
    this.set("autoCollapse", value);
  }

  @action
  setAlign(value) {
    this.set("align", value);
  }

  @action
  bumpColumns(delta) {
    const next = clamp(this.columns + delta, COLUMNS_MIN, COLUMNS_MAX);
    this._applyDimensionChange({ columns: next, rows: this.rows });
  }

  @action
  bumpRows(delta) {
    const next = clamp(this.rows + delta, ROWS_MIN, ROWS_MAX);
    this._applyDimensionChange({ columns: this.columns, rows: next });
  }

  /**
   * Shared path for `bumpColumns` / `bumpRows`. When the new bounds
   * would push existing slots out of range, prompt the user before
   * shrinking. On confirm: clamp slot placements first (one structural
   * undo entry), then write the new dimension arg (a second entry).
   * On cancel: do nothing.
   *
   * @param {{columns: number, rows: number}} next
   */
  _applyDimensionChange({ columns, rows }) {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return;
    }
    const offenders = this.wireframe.outOfBoundsSlotsIn(
      data.key,
      columns,
      rows
    );
    if (offenders.length === 0) {
      this._writeDimensions({ columns, rows });
      return;
    }
    this.dialog.confirm({
      message: i18n("wireframe.inspector.layout.clamp_slots_confirm", {
        count: offenders.length,
      }),
      confirmButtonLabel:
        "wireframe.inspector.layout.clamp_slots_confirm_action",
      didConfirm: () => {
        this.wireframe.clampGridSlotPlacements({
          gridKey: data.key,
          maxColumns: columns,
          maxRows: rows,
        });
        this._writeDimensions({ columns, rows });
      },
    });
  }

  _writeDimensions({ columns, rows }) {
    if (columns !== this.columns) {
      this.set("columns", columns);
    }
    if (rows !== this.rows) {
      this.set("rows", rows);
    }
  }

  /**
   * Clamps the already-out-of-bounds slot placements on an existing
   * layout. Triggered by the warning-banner button surfaced when the
   * layout loaded with bad data (e.g. someone edited the JSON by hand
   * or reduced columns in a previous session before the confirm flow
   * was wired up).
   */
  @action
  fixOutOfBoundsSlots() {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return;
    }
    this.wireframe.clampGridSlotPlacements({
      gridKey: data.key,
      maxColumns: this.columns,
      maxRows: this.rows,
    });
  }

  @action
  setGap(event) {
    const raw = Number(event.target.value);
    if (Number.isFinite(raw)) {
      this.set("gap", raw);
    }
  }

  @action
  setColumnTemplate(event) {
    this.set("columnTemplate", event.target.value);
  }

  @action
  setRowTemplate(event) {
    this.set("rowTemplate", event.target.value);
  }

  @action
  clearColumnTemplate() {
    this.set("columnTemplate", "");
  }

  @action
  clearRowTemplate() {
    this.set("rowTemplate", "");
  }

  get gridTemplates() {
    return GRID_TEMPLATES;
  }

  @action
  applyTemplate(template) {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return;
    }
    // Templates always switch the layout into `grid` mode — applying
    // one to a stack/row layout is the natural way to "convert" it.
    // The service handles the args overwrite atomically.
    this.wireframe.applyGridTemplate({
      gridKey: data.key,
      template,
    });
  }

  <template>
    <div class="wireframe-layout-form">
      <div class="wireframe-layout-form__field">
        <span class="wireframe-layout-form__legend">
          {{i18n "wireframe.inspector.layout.mode_legend"}}
        </span>
        <div class="wireframe-layout-form__segmented" role="radiogroup">
          {{#each MODES as |modeOption|}}
            <DButton
              class={{dConcatClass
                "wireframe-layout-form__segment"
                (if (eq this.mode modeOption.id) "--active")
              }}
              @ariaPressed={{eq this.mode modeOption.id}}
              @icon={{modeOption.icon}}
              @label={{concat
                "wireframe.inspector.layout."
                modeOption.labelKey
              }}
              @translatedTitle={{i18n
                (concat "wireframe.inspector.layout." modeOption.labelKey)
              }}
              @action={{fn this.setMode modeOption.id}}
            />
          {{/each}}
        </div>
      </div>

      {{! Auto-collapse selector — surfaces the @container behaviour
        from wireframe.scss and lets authors tune the threshold per
        layout. Hidden for stack mode (which is already column-oriented
        and has no @container rule). The help text under the segmented
        buttons updates based on the active selection. }}
      {{#unless (eq this.mode "stack")}}
        <div class="wireframe-layout-form__field">
          <span class="wireframe-layout-form__legend">
            {{i18n "wireframe.inspector.layout.auto_collapse_label"}}
          </span>
          <div class="wireframe-layout-form__segmented" role="radiogroup">
            {{#each AUTO_COLLAPSE_OPTIONS as |option|}}
              <DButton
                class={{dConcatClass
                  "wireframe-layout-form__segment"
                  (if (eq this.autoCollapse option.id) "--active")
                }}
                @ariaPressed={{eq this.autoCollapse option.id}}
                @label={{concat "wireframe.inspector.layout." option.labelKey}}
                @translatedTitle={{i18n
                  (concat "wireframe.inspector.layout." option.labelKey)
                }}
                @action={{fn this.setAutoCollapse option.id}}
              />
            {{/each}}
          </div>
          <p class="wireframe-layout-form__hint">
            {{dIcon "circle-info"}}
            <span>{{i18n this.autoCollapseHelpKey}}</span>
          </p>
        </div>
      {{/unless}}

      {{#if this.isGrid}}
        <div class="wireframe-layout-form__pair">
          <Stepper
            @label={{i18n "wireframe.inspector.layout.columns"}}
            @value={{this.columns}}
            @min={{COLUMNS_MIN}}
            @max={{COLUMNS_MAX}}
            @onBump={{this.bumpColumns}}
          />
          <Stepper
            @label={{i18n "wireframe.inspector.layout.rows"}}
            @value={{this.rows}}
            @min={{ROWS_MIN}}
            @max={{ROWS_MAX}}
            @onBump={{this.bumpRows}}
          />
        </div>

        {{! Loaded-with-bad-data warning: some slots reference cells
          outside the current grid. We can't auto-clamp on load (the
          user might have just opened a saved layout and not yet
          touched anything), so show a banner with a manual "Fix"
          action that routes through the same clamp helper. }}
        {{#if this.hasOutOfBoundsSlots}}
          <div class="wireframe-layout-form__warning" role="alert">
            {{dIcon "triangle-exclamation"}}
            <div class="wireframe-layout-form__warning-body">
              <p>{{i18n
                  "wireframe.inspector.layout.out_of_bounds_warning"
                  count=this.outOfBoundsSlots.length
                }}</p>
              <DButton
                class="btn-small btn-danger"
                @label="wireframe.inspector.layout.out_of_bounds_fix"
                @action={{this.fixOutOfBoundsSlots}}
              />
            </div>
          </div>
        {{/if}}
      {{/if}}

      <div class="wireframe-layout-form__field">
        <span class="wireframe-layout-form__legend">
          {{i18n "wireframe.inspector.layout.gap_legend"}}
        </span>
        <div class="wireframe-layout-form__slider-row">
          <input
            type="range"
            min={{GAP_MIN}}
            max={{GAP_MAX}}
            step={{GAP_STEP}}
            value={{this.gap}}
            {{on "input" this.setGap}}
          />
          <span class="wireframe-layout-form__slider-value">
            {{this.gap}}rem
          </span>
        </div>
      </div>

      <div class="wireframe-layout-form__field">
        <span class="wireframe-layout-form__legend">
          {{i18n "wireframe.inspector.layout.align_legend"}}
        </span>
        <div class="wireframe-layout-form__segmented" role="radiogroup">
          {{#each ALIGNMENTS as |value|}}
            <DButton
              class={{dConcatClass
                "wireframe-layout-form__segment"
                (if (eq this.align value) "--active")
              }}
              @ariaPressed={{eq this.align value}}
              @label={{concat "wireframe.inspector.layout.align_" value}}
              @action={{fn this.setAlign value}}
            />
          {{/each}}
        </div>
      </div>

      {{#if this.isGrid}}
        <div class="wireframe-layout-form__field">
          <span class="wireframe-layout-form__legend">
            {{i18n "wireframe.inspector.layout.templates_legend"}}
          </span>
          <div class="wireframe-layout-form__templates">
            {{#each this.gridTemplates as |template|}}
              <DButton
                class={{dConcatClass
                  "wireframe-layout-form__template-chip"
                  (unless (this.canApplyTemplate template) "--disabled")
                }}
                @disabled={{unless (this.canApplyTemplate template) true}}
                @translatedTitle={{if
                  (this.canApplyTemplate template)
                  (i18n
                    (concat
                      "wireframe.inspector.layout.templates." template.i18nKey
                    )
                  )
                  (i18n "wireframe.inspector.layout.template_cant_fit")
                }}
                @action={{fn this.applyTemplate template}}
              >
                <span class="wireframe-layout-form__template-preview">
                  <TemplatePreview @template={{template}} />
                </span>
                <span>{{i18n
                    (concat
                      "wireframe.inspector.layout.templates." template.i18nKey
                    )
                  }}</span>
              </DButton>
            {{/each}}
          </div>
        </div>

        {{! Disclosure body holds inputs/buttons by design. The
            <summary> is the disclosure trigger; its descendants
            stand on their own as form controls once expanded. }}
        <details class="wireframe-layout-form__advanced">
          <summary>{{i18n
              "wireframe.inspector.layout.advanced_templates"
            }}</summary>
          <div class="wireframe-layout-form__field">
            <span class="wireframe-layout-form__legend">
              {{i18n "wireframe.inspector.layout.column_template"}}
            </span>
            <div class="wireframe-layout-form__template-row">
              <input
                type="text"
                value={{this.columnTemplate}}
                placeholder="1fr 2fr 1fr"
                {{on "input" this.setColumnTemplate}}
              />
              {{#if this.columnTemplate}}
                <DButton
                  class="btn-flat btn-small"
                  @icon="rotate-left"
                  @title="wireframe.inspector.layout.template_clear"
                  @action={{this.clearColumnTemplate}}
                />
              {{/if}}
            </div>
          </div>
          <div class="wireframe-layout-form__field">
            <span class="wireframe-layout-form__legend">
              {{i18n "wireframe.inspector.layout.row_template"}}
            </span>
            <div class="wireframe-layout-form__template-row">
              <input
                type="text"
                value={{this.rowTemplate}}
                placeholder="auto 1fr"
                {{on "input" this.setRowTemplate}}
              />
              {{#if this.rowTemplate}}
                <DButton
                  class="btn-flat btn-small"
                  @icon="rotate-left"
                  @title="wireframe.inspector.layout.template_clear"
                  @action={{this.clearRowTemplate}}
                />
              {{/if}}
            </div>
          </div>
        </details>
      {{/if}}
    </div>
  </template>
}

/**
 * Inline stepper helper. Renders a label + ◀ / value / ▶. Used for
 * the integer args (columns, rows).
 */
class Stepper extends Component {
  @action
  decrement() {
    this.args.onBump(-1);
  }

  @action
  increment() {
    this.args.onBump(1);
  }

  get canDecrement() {
    return this.args.value > this.args.min;
  }

  get canIncrement() {
    return this.args.value < this.args.max;
  }

  <template>
    <div class="wireframe-layout-form__stepper">
      <span class="wireframe-layout-form__legend">{{@label}}</span>
      <div class="wireframe-layout-form__stepper-controls">
        <DButton
          class="wireframe-layout-form__stepper-btn"
          @icon="chevron-left"
          @disabled={{unless this.canDecrement true}}
          @action={{this.decrement}}
        />
        <span class="wireframe-layout-form__stepper-value">
          {{@value}}
        </span>
        <DButton
          class="wireframe-layout-form__stepper-btn"
          @icon="chevron-right"
          @disabled={{unless this.canIncrement true}}
          @action={{this.increment}}
        />
      </div>
    </div>
  </template>
}

/**
 * Mini representation of a template's grid layout. Renders one tile
 * per cell of the `columns × rows` grid, using the template's
 * `columnTemplate` / `rowTemplate` when set so unequal-column presets
 * (sidebar-main, asymmetric) read at their true proportions. Used in
 * the template-chip thumbnails so authors can preview a shape before
 * applying it.
 */
class TemplatePreview extends Component {
  /**
   * Parses the template's `areas` string once. Memoised on the
   * template object so repeated reads (Glimmer re-renders, multiple
   * preview tiles) don't reparse. Returns `null` for frame-only
   * templates so the cell-by-cell fallback takes over.
   */
  get parsedAreas() {
    const template = this.args.template;
    if (!template.areas) {
      return null;
    }
    if (template.__parsedAreas === undefined) {
      template.__parsedAreas = parseGridAreas(template.areas) ?? null;
    }
    return template.__parsedAreas;
  }

  get gridStyle() {
    const parsed = this.parsedAreas;
    const args = this.args.template.args;
    const cols = parsed?.columns ?? args.columns ?? 6;
    const rows = parsed?.rows ?? args.rows ?? 1;
    const columns =
      (args.columnTemplate ?? "").trim() || `repeat(${cols}, 1fr)`;
    const rowTemplate =
      (args.rowTemplate ?? "").trim() || `repeat(${rows}, 1fr)`;
    return trustHTML(
      `display: grid; grid-template-columns: ${columns}; ` +
        `grid-template-rows: ${rowTemplate}; gap: 2px;`
    );
  }

  get tiles() {
    // Templates with `areas` declare an explicit shape — one tile per
    // parsed slot rect. Frame-only templates render one tile per cell
    // of the grid.
    const parsed = this.parsedAreas;
    if (parsed) {
      return parsed.slots.map((slot) => ({
        style: trustHTML(`grid-column: ${slot.column}; grid-row: ${slot.row};`),
      }));
    }
    const args = this.args.template.args;
    const cols = Math.max(1, Number(args.columns ?? 1));
    const rows = Math.max(1, Number(args.rows ?? 1));
    const tiles = [];
    for (let r = 1; r <= rows; r++) {
      for (let c = 1; c <= cols; c++) {
        tiles.push({
          style: trustHTML(`grid-column: ${c}; grid-row: ${r};`),
        });
      }
    }
    return tiles;
  }

  <template>
    <span class="wireframe-layout-form__preview" style={{this.gridStyle}}>
      {{#each this.tiles as |tile|}}
        <span
          class="wireframe-layout-form__preview-tile"
          style={{tile.style}}
        ></span>
      {{/each}}
    </span>
  </template>
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
