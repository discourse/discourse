// @ts-check
import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { GRID_TEMPLATES } from "../../lib/grid-templates";

/**
 * Custom inspector form for the `ve:layout` block. The generic
 * FormKit form would show a bag of fields (mode, count, columns,
 * gap, ...) where most aren't relevant for the current mode. This
 * form swaps in mode-specific controls and uses richer affordances
 * (segmented selectors, steppers, sliders) instead of bare inputs.
 *
 * Live updates flow through `visualEditor.updateSelectedArg`, same
 * channel the generic form uses — the canvas reflects changes
 * without remounting the form.
 */
const MODES = [
  { id: "stack", labelKey: "mode_stack", icon: "arrow-down" },
  { id: "row", labelKey: "mode_row", icon: "arrow-right" },
  { id: "grid", labelKey: "mode_grid", icon: "grip" },
  { id: "free-grid", labelKey: "mode_free_grid", icon: "table-cells-large" },
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
  @service visualEditor;

  get args_() {
    return this.visualEditor.selectedBlockData?.args ?? {};
  }

  get mode() {
    return this.args_.mode ?? "stack";
  }

  get isFreeGrid() {
    return this.mode === "free-grid";
  }

  get isAutoGrid() {
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

  get count() {
    return this.args_.count ?? 2;
  }

  get columnTemplate() {
    return this.args_.columnTemplate ?? "";
  }

  get rowTemplate() {
    return this.args_.rowTemplate ?? "";
  }

  set(name, value) {
    this.visualEditor.updateSelectedArg(name, value);
  }

  @action
  setMode(mode) {
    this.set("mode", mode);
  }

  @action
  setAlign(value) {
    this.set("align", value);
  }

  @action
  bumpColumns(delta) {
    const next = clamp(this.columns + delta, COLUMNS_MIN, COLUMNS_MAX);
    this.set("columns", next);
  }

  @action
  bumpRows(delta) {
    const next = clamp(this.rows + delta, ROWS_MIN, ROWS_MAX);
    this.set("rows", next);
  }

  @action
  bumpCount(delta) {
    const next = clamp(this.count + delta, 2, 4);
    this.set("count", next);
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
    const data = this.visualEditor.selectedBlockData;
    if (!data?.key) {
      return;
    }
    if (data.argsSnapshot?.mode === "free-grid") {
      // Switching templates while authoring a free-grid is the common
      // case. Confirm only when there's existing content so we don't
      // nag on every template-pick during an empty start.
    }
    this.visualEditor.applyGridTemplate({
      gridKey: data.key,
      template,
    });
  }

  <template>
    <div class="visual-editor-layout-form">
      <div class="visual-editor-layout-form__field">
        <span class="visual-editor-layout-form__legend">
          {{i18n "visual_editor.inspector.layout.mode_legend"}}
        </span>
        <div class="visual-editor-layout-form__segmented" role="radiogroup">
          {{#each MODES as |modeOption|}}
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-layout-form__segment"
                (if (eq this.mode modeOption.id) "--active")
              }}
              role="radio"
              aria-checked={{eq this.mode modeOption.id}}
              title={{i18n
                (concat "visual_editor.inspector.layout." modeOption.labelKey)
              }}
              {{on "click" (fn this.setMode modeOption.id)}}
            >
              {{dIcon modeOption.icon}}
              <span>{{i18n
                  (concat "visual_editor.inspector.layout." modeOption.labelKey)
                }}</span>
            </button>
          {{/each}}
        </div>
      </div>

      {{#if this.isFreeGrid}}
        <div class="visual-editor-layout-form__pair">
          <Stepper
            @label={{i18n "visual_editor.inspector.layout.columns"}}
            @value={{this.columns}}
            @min={{COLUMNS_MIN}}
            @max={{COLUMNS_MAX}}
            @onBump={{this.bumpColumns}}
          />
          <Stepper
            @label={{i18n "visual_editor.inspector.layout.rows"}}
            @value={{this.rows}}
            @min={{ROWS_MIN}}
            @max={{ROWS_MAX}}
            @onBump={{this.bumpRows}}
          />
        </div>
      {{else if this.isAutoGrid}}
        <div class="visual-editor-layout-form__pair">
          <Stepper
            @label={{i18n "visual_editor.inspector.layout.count"}}
            @value={{this.count}}
            @min={{2}}
            @max={{4}}
            @onBump={{this.bumpCount}}
          />
        </div>
      {{/if}}

      <div class="visual-editor-layout-form__field">
        <span class="visual-editor-layout-form__legend">
          {{i18n "visual_editor.inspector.layout.gap_legend"}}
        </span>
        <div class="visual-editor-layout-form__slider-row">
          <input
            type="range"
            min={{GAP_MIN}}
            max={{GAP_MAX}}
            step={{GAP_STEP}}
            value={{this.gap}}
            {{on "input" this.setGap}}
          />
          <span class="visual-editor-layout-form__slider-value">
            {{this.gap}}rem
          </span>
        </div>
      </div>

      <div class="visual-editor-layout-form__field">
        <span class="visual-editor-layout-form__legend">
          {{i18n "visual_editor.inspector.layout.align_legend"}}
        </span>
        <div class="visual-editor-layout-form__segmented" role="radiogroup">
          {{#each ALIGNMENTS as |value|}}
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-layout-form__segment"
                (if (eq this.align value) "--active")
              }}
              role="radio"
              aria-checked={{eq this.align value}}
              {{on "click" (fn this.setAlign value)}}
            >
              {{i18n (concat "visual_editor.inspector.layout.align_" value)}}
            </button>
          {{/each}}
        </div>
      </div>

      {{#if this.isFreeGrid}}
        <div class="visual-editor-layout-form__field">
          <span class="visual-editor-layout-form__legend">
            {{i18n "visual_editor.inspector.layout.templates_legend"}}
          </span>
          <div class="visual-editor-layout-form__templates">
            {{#each this.gridTemplates as |template|}}
              <button
                type="button"
                class="visual-editor-layout-form__template-chip"
                title={{i18n
                  (concat
                    "visual_editor.inspector.layout.templates." template.i18nKey
                  )
                }}
                {{on "click" (fn this.applyTemplate template)}}
              >
                <span class="visual-editor-layout-form__template-preview">
                  <TemplatePreview @template={{template}} />
                </span>
                <span>{{i18n
                    (concat
                      "visual_editor.inspector.layout.templates."
                      template.i18nKey
                    )
                  }}</span>
              </button>
            {{/each}}
          </div>
        </div>

        {{! template-lint-disable no-nested-interactive }}
        {{! Disclosure body holds inputs/buttons by design. The
            <summary> is the disclosure trigger; its descendants
            stand on their own as form controls once expanded. }}
        <details class="visual-editor-layout-form__advanced">
          <summary>{{i18n
              "visual_editor.inspector.layout.advanced_templates"
            }}</summary>
          <div class="visual-editor-layout-form__field">
            <span class="visual-editor-layout-form__legend">
              {{i18n "visual_editor.inspector.layout.column_template"}}
            </span>
            <div class="visual-editor-layout-form__template-row">
              <input
                type="text"
                value={{this.columnTemplate}}
                placeholder="1fr 2fr 1fr"
                {{on "input" this.setColumnTemplate}}
              />
              {{#if this.columnTemplate}}
                <button
                  type="button"
                  class="btn btn-flat btn-small"
                  title={{i18n "visual_editor.inspector.layout.template_clear"}}
                  {{on "click" this.clearColumnTemplate}}
                >
                  {{dIcon "rotate-left"}}
                </button>
              {{/if}}
            </div>
          </div>
          <div class="visual-editor-layout-form__field">
            <span class="visual-editor-layout-form__legend">
              {{i18n "visual_editor.inspector.layout.row_template"}}
            </span>
            <div class="visual-editor-layout-form__template-row">
              <input
                type="text"
                value={{this.rowTemplate}}
                placeholder="auto 1fr"
                {{on "input" this.setRowTemplate}}
              />
              {{#if this.rowTemplate}}
                <button
                  type="button"
                  class="btn btn-flat btn-small"
                  title={{i18n "visual_editor.inspector.layout.template_clear"}}
                  {{on "click" this.clearRowTemplate}}
                >
                  {{dIcon "rotate-left"}}
                </button>
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
 * the integer args (columns, rows, count).
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
    <div class="visual-editor-layout-form__stepper">
      <span class="visual-editor-layout-form__legend">{{@label}}</span>
      <div class="visual-editor-layout-form__stepper-controls">
        <button
          type="button"
          class="visual-editor-layout-form__stepper-btn"
          disabled={{if this.canDecrement undefined "disabled"}}
          {{on "click" this.decrement}}
        >
          {{dIcon "chevron-left"}}
        </button>
        <span class="visual-editor-layout-form__stepper-value">
          {{@value}}
        </span>
        <button
          type="button"
          class="visual-editor-layout-form__stepper-btn"
          disabled={{if this.canIncrement undefined "disabled"}}
          {{on "click" this.increment}}
        >
          {{dIcon "chevron-right"}}
        </button>
      </div>
    </div>
  </template>
}

/**
 * Tiny SVG mock of a template's grid layout — renders the template's
 * args.columns × args.rows as a grid of small rectangles, with the
 * preset's slots overlaid as solid tiles. Used in the template-chip
 * thumbnails so authors can preview a layout before applying it.
 */
class TemplatePreview extends Component {
  get gridStyle() {
    const args = this.args.template.args;
    const columns =
      (args.columnTemplate ?? "").trim() || `repeat(${args.columns ?? 6}, 1fr)`;
    const rows =
      (args.rowTemplate ?? "").trim() || `repeat(${args.rows ?? 1}, 1fr)`;
    return trustHTML(
      `display: grid; grid-template-columns: ${columns}; ` +
        `grid-template-rows: ${rows}; gap: 1px;`
    );
  }

  get tiles() {
    const slots = this.args.template.slots ?? [];
    if (slots.length === 0) {
      // 12-col baseline — render a single full-width strip so the
      // preview isn't empty.
      const args = this.args.template.args;
      return [
        {
          style: trustHTML(
            `grid-column: 1 / ${(args.columns ?? 12) + 1}; grid-row: 1;`
          ),
        },
      ];
    }
    return slots.map((slot) => ({
      style: trustHTML(
        `grid-column: ${slot.args.column}; grid-row: ${slot.args.row};`
      ),
    }));
  }

  <template>
    <span class="visual-editor-layout-form__preview" style={{this.gridStyle}}>
      {{#each this.tiles as |tile|}}
        <span
          class="visual-editor-layout-form__preview-tile"
          style={{tile.style}}
        ></span>
      {{/each}}
    </span>
  </template>
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}
