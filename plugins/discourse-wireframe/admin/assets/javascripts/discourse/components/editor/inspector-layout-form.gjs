// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import Form from "discourse/components/form";
import DMenu from "discourse/float-kit/components/d-menu";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { friendlyErrorMessage } from "discourse/plugins/discourse-wireframe/discourse/lib/friendly-error-message";
import { GRID_TEMPLATES, parseGridAreas } from "../../lib/grid-templates";
import { buildValidationRule } from "../../lib/schema-to-fields";
import InspectorDimensionField from "./inspector-dimension-field";
import InspectorSegmentedField from "./inspector-segmented-field";
import InspectorStepperField from "./inspector-stepper-field";

/**
 * Custom inspector form for the `wf:layout` block. The generic
 * FormKit form would show a bag of fields (mode, columns,
 * gap, ...) where most aren't relevant for the current mode. This
 * form swaps in mode-specific controls and uses richer affordances
 * (segmented selectors, a template dropdown, sliders) instead of bare
 * inputs.
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
const JUSTIFY_CONTENT = [
  "start",
  "center",
  "end",
  "space-between",
  "space-around",
  "space-evenly",
];
const JUSTIFY_ITEMS = ["start", "center", "end", "stretch"];
const ALIGN_CONTENT = [
  "start",
  "center",
  "end",
  "space-between",
  "space-around",
  "stretch",
];
const WRAP = ["wrap", "nowrap"];

// Lucide (`wf-`) icon glyphs keyed by axis orientation. A flex layout's main /
// cross axis depends on its mode (stack = vertical main, row & grid = horizontal),
// so alignment and distribution icons are chosen per orientation; the value's
// label rides along as the tooltip / accessible name.
const ALIGN_ICONS = {
  horizontal: {
    start: "wf-align-start-horizontal",
    center: "wf-align-center-horizontal",
    end: "wf-align-end-horizontal",
    stretch: "wf-stretch-horizontal",
  },
  vertical: {
    start: "wf-align-start-vertical",
    center: "wf-align-center-vertical",
    end: "wf-align-end-vertical",
    stretch: "wf-stretch-vertical",
  },
};
const JUSTIFY_CONTENT_ICONS = {
  horizontal: {
    start: "wf-align-horizontal-justify-start",
    center: "wf-align-horizontal-justify-center",
    end: "wf-align-horizontal-justify-end",
    "space-between": "wf-align-horizontal-space-between",
    "space-around": "wf-align-horizontal-space-around",
    "space-evenly": "wf-align-horizontal-distribute-center",
  },
  vertical: {
    start: "wf-align-vertical-justify-start",
    center: "wf-align-vertical-justify-center",
    end: "wf-align-vertical-justify-end",
    "space-between": "wf-align-vertical-space-between",
    "space-around": "wf-align-vertical-space-around",
    "space-evenly": "wf-align-vertical-distribute-center",
  },
};
// Grid only: per-cell alignment along the inline (horizontal) axis.
const JUSTIFY_ITEMS_ICONS = {
  start: "wf-align-start-vertical",
  center: "wf-align-center-vertical",
  end: "wf-align-end-vertical",
  stretch: "wf-stretch-horizontal",
};
// Grid only: track distribution along the block (vertical) axis.
const ALIGN_CONTENT_ICONS = {
  start: "wf-align-vertical-justify-start",
  center: "wf-align-vertical-justify-center",
  end: "wf-align-vertical-justify-end",
  "space-between": "wf-align-vertical-space-between",
  "space-around": "wf-align-vertical-space-around",
  stretch: "wf-stretch-vertical",
};
const WRAP_ICONS = { wrap: "wf-wrap-text", nowrap: "wf-move-horizontal" };

const COLUMNS_MIN = 1;
const COLUMNS_MAX = 12;
const ROWS_MIN = 1;
const ROWS_MAX = 8;
const GAP_MIN = 0;
const GAP_MAX = 4;
const GAP_STEP = 0.25;

export default class InspectorLayoutForm extends Component {
  @service wireframe;
  @service wireframeArgEdit;
  @service wireframeGridTemplate;
  @service dialog;

  /**
   * FormKit's external-error API, captured from `<Form @onRegisterApi>`. Used
   * by `syncErrors` to push the service's structured validation errors into the
   * matching field's error slot. Plain field (not `@tracked`): the sync runs
   * from the `{{didInsert}}` / `{{didUpdate}}` modifiers, never read from a
   * template.
   *
   * @type {{addError: Function, removeErrors: Function}|null}
   */
  #formApi = null;

  /**
   * Predicate the template menu uses to grey out templates that can't
   * fit the current layout (one with fewer spaces than the layout has
   * content blocks). Delegates to the service so the refusal logic
   * lives next to `applyGridTemplate` and the two stay in lockstep.
   */
  #canApplyTemplate = (template) => {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return false;
    }
    return this.wireframeGridTemplate.canApplyGridTemplate({
      gridKey: data.key,
      template,
    });
  };

  /**
   * The preset template whose shape matches the current grid, or `null`
   * when none does — derived from geometry by the service, so it tracks
   * hand edits without a stored id. Drives the Free / Template control
   * and the active-preset highlight in the dropdown.
   *
   * @returns {Object|null}
   */
  get #activeTemplate() {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return null;
    }
    return this.wireframeGridTemplate.activeGridTemplate(data.key);
  }

  /**
   * `true` when the grid has no matching preset — i.e. it's a plain
   * free grid. The Free control is selected and the column / row fields
   * show in this state.
   *
   * @returns {boolean}
   */
  get isFree() {
    return !this.#activeTemplate;
  }

  /**
   * Translated label for the template dropdown button: the active
   * preset's name, or a "choose a template" prompt when free.
   *
   * @returns {string}
   */
  get templateButtonLabel() {
    const active = this.#activeTemplate;
    return active
      ? i18n(`wireframe.inspector.layout.templates.${active.i18nKey}`)
      : i18n("wireframe.inspector.layout.choose_template");
  }

  /**
   * The preset rows for the dropdown menu: each template with whether it
   * fits the current content and whether it's the active one.
   *
   * @returns {Array<{template: Object, canApply: boolean, isActive: boolean}>}
   */
  get templateOptions() {
    const active = this.#activeTemplate;
    return GRID_TEMPLATES.map((template) => ({
      template,
      canApply: this.#canApplyTemplate(template),
      isActive: template.id === active?.id,
    }));
  }

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
    return this.wireframeGridTemplate.outOfBoundsSlotsIn(
      data.key,
      this.columns,
      this.rows
    );
  }

  get hasOutOfBoundsSlots() {
    return this.outOfBoundsSlots.length > 0;
  }

  get #args() {
    return this.wireframe.selectedBlockData?.args ?? {};
  }

  /**
   * The block's declared args schema for the current selection (its `ui` hints,
   * defaults, and constraints). Empty when nothing is declared.
   *
   * @returns {Object}
   */
  get #schema() {
    return this.wireframe.selectedBlockData?.metadata?.args ?? {};
  }

  /**
   * Seed data for `<Form @data>`. Starts from each arg's schema default, then
   * overlays the selection's `argsSnapshot` (a frozen plain copy captured once
   * at selection). The defaults matter because the snapshot only carries
   * explicitly-set args — without them a draft-bound control (align, gap, …)
   * for an unset arg would render blank instead of its effective default.
   *
   * `@cached` so the reference stays stable for the life of a selection: Form
   * seeds FKFormData once and only remounts when this reference changes, so we
   * recompute solely when the selection (and thus the snapshot / schema) does,
   * never per keystroke.
   *
   * @returns {Object}
   */
  @cached
  get argsSnapshot() {
    const snapshot = this.wireframe.selectedBlockData?.argsSnapshot ?? {};
    const defaults = {};
    for (const [name, def] of Object.entries(this.#schema)) {
      if (def?.default !== undefined) {
        defaults[name] = def.default;
      }
    }
    return { ...defaults, ...snapshot };
  }

  /**
   * Subscribes the surrounding tracking frame to the service's structured
   * field-errors map, so the `{{didUpdate}}`-driven `syncErrors` re-runs when
   * the validator's stamps change. Returns the map for iteration inside the
   * sync without taking a second tracked dep.
   *
   * @returns {Object<string, Array<Object>>}
   */
  @cached
  get fieldErrors() {
    return this.wireframe.selectedBlockFieldErrors;
  }

  get mode() {
    // Coerce the legacy `"free-grid"` mode value to `"grid"` so the
    // segmented control highlights the right segment and the rest of
    // the form behaves consistently with the new naming.
    const raw = this.#args.mode ?? "stack";
    return raw === "free-grid" ? "grid" : raw;
  }

  get isGrid() {
    return this.mode === "grid";
  }

  /**
   * Effective column / row counts — the larger of the declared args and
   * what the grid's children occupy, read from the service so the fields
   * always match the rendered grid (never a bare default that drifts).
   *
   * @returns {number}
   */
  get columns() {
    const data = this.wireframe.selectedBlockData;
    return data?.key
      ? this.wireframeGridTemplate.gridSizeFor(data.key).columns
      : 3;
  }

  get rows() {
    const data = this.wireframe.selectedBlockData;
    return data?.key
      ? this.wireframeGridTemplate.gridSizeFor(data.key).rows
      : 2;
  }

  /** @returns {boolean} `true` for the flex modes (stack / row). */
  get isFlex() {
    return this.mode === "stack" || this.mode === "row";
  }

  /** @returns {boolean} `true` only in row mode (where wrap is meaningful). */
  get isRow() {
    return this.mode === "row";
  }

  get columnTemplate() {
    return this.#args.columnTemplate ?? "";
  }

  get rowTemplate() {
    return this.#args.rowTemplate ?? "";
  }

  get autoCollapse() {
    return this.#args.autoCollapse ?? "default";
  }

  /**
   * i18n key for the dynamic help text beneath the auto-collapse
   * segmented selector. Keys follow the `auto_collapse_help_{value}`
   * pattern — one per enum value.
   */
  get autoCollapseHelpKey() {
    return `wireframe.inspector.layout.auto_collapse_help_${this.autoCollapse}`;
  }

  /**
   * Glyph orientation for the alignment / justify icons: a stack's axes are the
   * mirror of a row's (and grid reads like a row), so stack mode uses the
   * vertical glyph set and everything else the horizontal one.
   *
   * @returns {"horizontal"|"vertical"}
   */
  get #glyphAxis() {
    return this.mode === "stack" ? "vertical" : "horizontal";
  }

  /**
   * Items for the unified enum field — `{value, label, icon, title}`. The label
   * doubles as the tooltip / accessible name and the dropdown-fallback text.
   *
   * @returns {Array<{value: string, label: string, icon: string}>}
   */
  get modeItems() {
    return MODES.map((mode) => {
      const label = i18n(`wireframe.inspector.layout.${mode.labelKey}`);
      return { value: mode.id, label, title: label, icon: mode.icon };
    });
  }

  /** @returns {Array<{value: string, label: string}>} */
  get autoCollapseItems() {
    return AUTO_COLLAPSE_OPTIONS.map((option) => {
      const label = i18n(`wireframe.inspector.layout.${option.labelKey}`);
      return { value: option.id, label, title: label };
    });
  }

  /** @returns {Array<{value: string, label: string, icon: string}>} */
  get alignItems() {
    const icons = ALIGN_ICONS[this.#glyphAxis];
    return ALIGNMENTS.map((value) => {
      const label = i18n(`wireframe.inspector.layout.align_${value}`);
      return { value, label, title: label, icon: icons[value] };
    });
  }

  /** @returns {Array<{value: string, label: string, icon: string}>} */
  get justifyContentItems() {
    const icons = JUSTIFY_CONTENT_ICONS[this.#glyphAxis];
    return JUSTIFY_CONTENT.map((value) => {
      const label = i18n(
        `wireframe.inspector.layout.justify_${underscore(value)}`
      );
      return { value, label, title: label, icon: icons[value] };
    });
  }

  /** @returns {Array<{value: string, label: string, icon: string}>} */
  get alignContentItems() {
    return ALIGN_CONTENT.map((value) => {
      const label = i18n(
        `wireframe.inspector.layout.align_content_${underscore(value)}`
      );
      return { value, label, title: label, icon: ALIGN_CONTENT_ICONS[value] };
    });
  }

  /** @returns {Array<{value: string, label: string, icon: string}>} */
  get justifyItemsItems() {
    return JUSTIFY_ITEMS.map((value) => {
      const label = i18n(`wireframe.inspector.layout.justify_items_${value}`);
      return { value, label, title: label, icon: JUSTIFY_ITEMS_ICONS[value] };
    });
  }

  /** @returns {Array<{value: string, label: string, icon: string}>} */
  get wrapItems() {
    return WRAP.map((value) => {
      const label = i18n(`wireframe.inspector.layout.wrap_${value}`);
      return { value, label, title: label, icon: WRAP_ICONS[value] };
    });
  }

  @action
  setMode(mode) {
    this.#set("mode", mode);
  }

  @action
  setAutoCollapse(value) {
    this.#set("autoCollapse", value);
  }

  @action
  setColumns(value) {
    if (!Number.isFinite(value)) {
      return;
    }
    const next = clamp(value, COLUMNS_MIN, COLUMNS_MAX);
    this.#applyDimensionChange({ columns: next, rows: this.rows });
  }

  @action
  setRows(value) {
    if (!Number.isFinite(value)) {
      return;
    }
    const next = clamp(value, ROWS_MIN, ROWS_MAX);
    this.#applyDimensionChange({ columns: this.columns, rows: next });
  }

  /**
   * Switches the layout into free mode at its current dimensions:
   * content reflows into a plain `columns × rows` grid (a preset's
   * spans collapse to single cells). No-op when already free.
   */
  @action
  chooseFree() {
    if (this.isFree) {
      return;
    }
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return;
    }
    this.wireframeGridTemplate.applyFreeGrid({
      gridKey: data.key,
      columns: this.columns,
      rows: this.rows,
    });
  }

  /**
   * Clamps the already-out-of-bounds slot placements on an existing
   * layout. Triggered by the warning-banner button surfaced when the
   * layout loaded with bad data (e.g. someone edited the JSON by hand).
   */
  @action
  fixOutOfBoundsSlots() {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return;
    }
    this.wireframeGridTemplate.clampGridSlotPlacements({
      gridKey: data.key,
      maxColumns: this.columns,
      maxRows: this.rows,
    });
  }

  @action
  setColumnTemplate(event) {
    this.#set("columnTemplate", event.target.value);
  }

  @action
  setRowTemplate(event) {
    this.#set("rowTemplate", event.target.value);
  }

  @action
  clearColumnTemplate() {
    this.#set("columnTemplate", "");
  }

  @action
  clearRowTemplate() {
    this.#set("rowTemplate", "");
  }

  @action
  applyTemplate(template) {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return;
    }
    // Templates always switch the layout into `grid` mode — applying
    // one to a stack/row layout is the natural way to "convert" it.
    // The service reflows existing content into the new shape.
    this.wireframeGridTemplate.applyGridTemplate({
      gridKey: data.key,
      template,
    });
  }

  /**
   * Per-field `@onSet` for the draft-bound controls. FormKit calls it with the
   * new value and a context whose `set` applies it to FormKit's own draft. We
   * invoke both: `set` keeps the input in sync, and `updateSelectedArg` pushes
   * the change to the editor service so the canvas re-renders (debounced into
   * one undo entry). The service-live controls (mode / columns / rows) bypass
   * this and commit through their own actions.
   *
   * @param {*} value
   * @param {{set: Function, name: string}} ctx
   */
  @action
  async onFieldSet(value, ctx) {
    const argDef = this.#schema?.[ctx.name];
    // Treat an empty string as absence for string args without a default, so a
    // cleared field deletes the override rather than writing a literal "".
    const writeValue =
      value === "" && argDef?.default === undefined ? null : value;
    await ctx.set(ctx.name, value);
    this.wireframeArgEdit.updateSelectedArg(ctx.name, writeValue);
  }

  /**
   * Captures FormKit's external-error API when the Form mounts. The first
   * `syncErrors` runs immediately after via the host's `{{didInsert}}`.
   *
   * @param {{addError: Function, removeErrors: Function}} api
   */
  @action
  registerFormApi(api) {
    this.#formApi = api;
  }

  /**
   * Pushes the service's structured validation errors into FormKit, which then
   * renders each under its matching field and in the form-level summary. Runs
   * on mount and whenever `fieldErrors` OR `mode` changes — re-running on a mode
   * switch matters because FormKit drops a field's error when the field
   * unregisters (a grid-only field hidden in stack mode), so we re-push after
   * the visible field set changes. Non-field errors route through synthetic
   * `_block:<n>` keys (no title) so the summary renders them form-level.
   */
  @action
  syncErrors() {
    if (!this.#formApi) {
      return;
    }
    this.#formApi.removeErrors();
    for (const [field, details] of Object.entries(this.fieldErrors ?? {})) {
      const label = this.#schema?.[field]?.ui?.label ?? field;
      for (const detail of details) {
        this.#formApi.addError(field, {
          title: label,
          message: friendlyErrorMessage(detail),
        });
      }
    }
    (this.wireframe.selectedBlockNonFieldErrors ?? []).forEach((detail, i) => {
      this.#formApi.addError(`_block:${i}`, {
        message: friendlyErrorMessage(detail),
      });
    });
  }

  /**
   * Builds the FormKit `@validation` rule string for an arg from its schema
   * constraints (`min`/`max`/`minLength`/`maxLength`/`required`), or `undefined`
   * when the arg declares none — so the prop can be omitted.
   *
   * @param {string} argName
   * @returns {string|undefined}
   */
  @action
  validationRuleFor(argName) {
    const argDef = this.#schema?.[argName];
    if (!argDef) {
      return undefined;
    }
    return buildValidationRule({ required: argDef.required, schema: argDef });
  }

  #set(name, value) {
    this.wireframeArgEdit.updateSelectedArg(name, value);
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
  #applyDimensionChange({ columns, rows }) {
    const data = this.wireframe.selectedBlockData;
    if (!data?.key) {
      return;
    }
    const offenders = this.wireframeGridTemplate.outOfBoundsSlotsIn(
      data.key,
      columns,
      rows
    );
    if (offenders.length === 0) {
      this.#writeDimensions({ columns, rows });
      return;
    }
    this.dialog.confirm({
      message: i18n("wireframe.inspector.layout.clamp_slots_confirm", {
        count: offenders.length,
      }),
      confirmButtonLabel:
        "wireframe.inspector.layout.clamp_slots_confirm_action",
      didConfirm: () => {
        this.wireframeGridTemplate.clampGridSlotPlacements({
          gridKey: data.key,
          maxColumns: columns,
          maxRows: rows,
        });
        this.#writeDimensions({ columns, rows });
      },
    });
  }

  #writeDimensions({ columns, rows }) {
    if (columns !== this.columns) {
      this.#set("columns", columns);
    }
    if (rows !== this.rows) {
      this.#set("rows", rows);
    }
  }

  <template>
    {{! The host carries the error-sync side effect. It re-runs on mount, when
      the validator's field errors change, and when mode changes, because
      FormKit drops a field's pushed error when that field unregisters (a
      grid-only field hidden in stack mode), so we re-push after the visible
      field set changes. }}
    <div
      class="wireframe-layout-form"
      {{didInsert this.syncErrors}}
      {{didUpdate this.syncErrors this.fieldErrors this.mode}}
    >
      <Form
        @data={{this.argsSnapshot}}
        @onRegisterApi={{this.registerFormApi}}
        class="wireframe-inspector-form"
        as |form|
      >
        {{! Mode is service-live: it drives the conditional visibility below and
          coerces the legacy free-grid value, so it reads the live getter rather
          than the FormKit draft. }}
        <form.Field
          @name="mode"
          @title={{i18n "wireframe.inspector.layout.mode_legend"}}
          @type="custom"
          as |f|
        >
          <f.Control>
            <InspectorSegmentedField
              @items={{this.modeItems}}
              @value={{this.mode}}
              @onChange={{this.setMode}}
              @name="wireframe-layout-mode"
            />
          </f.Control>
        </form.Field>

        {{! Auto-collapse surfaces the responsive collapse behaviour and lets
          authors tune the threshold per layout. Hidden in stack mode (already
          column-oriented). Service-live so the dynamic help text below reads the
          current value. }}
        {{#unless (eq this.mode "stack")}}
          <form.Field
            @name="autoCollapse"
            @title={{i18n "wireframe.inspector.layout.auto_collapse_label"}}
            @type="custom"
            as |f|
          >
            <f.Control>
              <InspectorSegmentedField
                @items={{this.autoCollapseItems}}
                @value={{this.autoCollapse}}
                @onChange={{this.setAutoCollapse}}
                @name="wireframe-layout-auto-collapse"
              />
            </f.Control>
          </form.Field>
          <p class="wireframe-layout-form__hint">
            {{dIcon "circle-info"}}
            <span>{{i18n this.autoCollapseHelpKey}}</span>
          </p>
        {{/unless}}

        {{#if this.isGrid}}
          {{! Source picker: a bespoke widget (Free toggle plus a preset menu),
            not a single arg, so it stays plain markup inside the form. The
            active option is derived from the grid's current shape. }}
          <div class="wireframe-layout-form__field">
            <span class="wireframe-layout-form__legend">
              {{i18n "wireframe.inspector.layout.source_legend"}}
            </span>
            <div class="wireframe-layout-form__source" role="radiogroup">
              <DButton
                class={{dConcatClass
                  "wireframe-layout-form__source-option"
                  (if this.isFree "--active")
                }}
                @ariaPressed={{this.isFree}}
                @icon="table-cells"
                @label="wireframe.inspector.layout.free"
                @action={{this.chooseFree}}
              />
              <DMenu
                @identifier="wireframe-grid-templates"
                @placement="bottom-start"
                @icon="chevron-down"
                @label={{this.templateButtonLabel}}
                class={{dConcatClass
                  "wireframe-layout-form__source-option"
                  "wireframe-layout-form__template-dropdown"
                  (unless this.isFree "--active")
                }}
              >
                <:content as |args|>
                  <TemplateMenuList
                    @options={{this.templateOptions}}
                    @onPick={{this.applyTemplate}}
                    @close={{args.close}}
                  />
                </:content>
              </DMenu>
            </div>
          </div>

          {{! Columns and rows are service-live: the displayed value is the
            derived grid size, and editing routes through a clamp-confirm flow,
            so they read the live getters and commit through their own actions
            rather than the FormKit draft. }}
          <div class="wireframe-layout-form__pair">
            <form.Field
              @name="columns"
              @title={{i18n "wireframe.inspector.layout.columns"}}
              @type="custom"
              as |f|
            >
              <f.Control>
                <InspectorStepperField
                  @value={{this.columns}}
                  @onChange={{this.setColumns}}
                  @min={{COLUMNS_MIN}}
                  @max={{COLUMNS_MAX}}
                  @ariaLabel={{i18n "wireframe.inspector.layout.columns"}}
                />
              </f.Control>
            </form.Field>
            <form.Field
              @name="rows"
              @title={{i18n "wireframe.inspector.layout.rows"}}
              @type="custom"
              as |f|
            >
              <f.Control>
                <InspectorStepperField
                  @value={{this.rows}}
                  @onChange={{this.setRows}}
                  @min={{ROWS_MIN}}
                  @max={{ROWS_MAX}}
                  @ariaLabel={{i18n "wireframe.inspector.layout.rows"}}
                />
              </f.Control>
            </form.Field>
          </div>

          {{! Loaded-with-bad-data warning: some cells reference positions
            outside the current grid. We cannot auto-clamp on load, so show a
            banner with a manual fix action that routes through the clamp
            helper. }}
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

        {{! Gap, alignment, and distribution are draft-bound: the control reads
          and writes the FormKit field value, and onFieldSet mirrors the change
          to the editor service. The axis-aware item icons still come from the
          component getters, so they flip with the current mode. }}
        <form.Field
          @name="gap"
          @title={{i18n "wireframe.inspector.layout.gap_legend"}}
          @type="custom"
          @onSet={{this.onFieldSet}}
          @validation={{this.validationRuleFor "gap"}}
          as |f|
        >
          <f.Control>
            <InspectorDimensionField
              @custom={{f}}
              @unitless={{true}}
              @unit="rem"
              @slider={{true}}
              @min={{GAP_MIN}}
              @max={{GAP_MAX}}
              @step={{GAP_STEP}}
            />
          </f.Control>
        </form.Field>

        <form.Field
          @name="align"
          @title={{i18n "wireframe.inspector.layout.align_legend"}}
          @type="custom"
          @onSet={{this.onFieldSet}}
          as |f|
        >
          <f.Control>
            <InspectorSegmentedField
              @items={{this.alignItems}}
              @custom={{f}}
              @name="wireframe-layout-align"
            />
          </f.Control>
        </form.Field>

        <form.Field
          @name="justifyContent"
          @title={{i18n "wireframe.inspector.layout.justify_content_legend"}}
          @type="custom"
          @onSet={{this.onFieldSet}}
          as |f|
        >
          <f.Control>
            <InspectorSegmentedField
              @items={{this.justifyContentItems}}
              @custom={{f}}
              @name="wireframe-layout-justify-content"
            />
          </f.Control>
        </form.Field>

        {{#if this.isFlex}}
          <form.Field
            @name="reverse"
            @title={{i18n "wireframe.inspector.layout.reverse_legend"}}
            @type="toggle"
            @onSet={{this.onFieldSet}}
            as |f|
          >
            <f.Control />
          </form.Field>

          {{#if this.isRow}}
            <form.Field
              @name="wrap"
              @title={{i18n "wireframe.inspector.layout.wrap_legend"}}
              @type="custom"
              @onSet={{this.onFieldSet}}
              as |f|
            >
              <f.Control>
                <InspectorSegmentedField
                  @items={{this.wrapItems}}
                  @custom={{f}}
                  @name="wireframe-layout-wrap"
                />
              </f.Control>
            </form.Field>
          {{/if}}
        {{/if}}

        {{#if this.isGrid}}
          <form.Field
            @name="justifyItems"
            @title={{i18n "wireframe.inspector.layout.justify_items_legend"}}
            @type="custom"
            @onSet={{this.onFieldSet}}
            as |f|
          >
            <f.Control>
              <InspectorSegmentedField
                @items={{this.justifyItemsItems}}
                @custom={{f}}
                @name="wireframe-layout-justify-items"
              />
            </f.Control>
          </form.Field>

          <form.Field
            @name="alignContent"
            @title={{i18n "wireframe.inspector.layout.align_content_legend"}}
            @type="custom"
            @onSet={{this.onFieldSet}}
            as |f|
          >
            <f.Control>
              <InspectorSegmentedField
                @items={{this.alignContentItems}}
                @custom={{f}}
                @name="wireframe-layout-align-content"
              />
            </f.Control>
          </form.Field>

          <form.Field
            @name="dense"
            @title={{i18n "wireframe.inspector.layout.dense_legend"}}
            @type="toggle"
            @onSet={{this.onFieldSet}}
            as |f|
          >
            <f.Control />
          </form.Field>

          {{! Advanced disclosure holds the raw track-template escape hatches.
            They keep a bespoke clear button and write on every keystroke, so
            they stay plain inputs rather than fields. }}
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
      </Form>
    </div>
  </template>
}

/**
 * Body of the template-picker dropdown (rendered inside `<DMenu>`'s
 * `:content`). Takes `@options` (each `{template, canApply, isActive}`),
 * an `@onPick` callback, and FloatKit's `@close`. Each row shows the
 * template's preview + name; the active one is marked, and rows that
 * can't hold the current content are disabled with an explanatory
 * title. Picking a row applies the template and closes the menu.
 */
class TemplateMenuList extends Component {
  @action
  pick(template) {
    this.args.onPick?.(template);
    this.args.close?.();
  }

  <template>
    <div class="wireframe-template-menu" role="menu">
      {{#each @options as |option|}}
        <DButton
          class={{dConcatClass
            "wireframe-template-menu__item"
            (if option.isActive "--active")
            (unless option.canApply "--disabled")
          }}
          role="menuitemradio"
          @ariaPressed={{option.isActive}}
          @disabled={{unless option.canApply true}}
          @translatedTitle={{if
            option.canApply
            (i18n
              (concat
                "wireframe.inspector.layout.templates." option.template.i18nKey
              )
            )
            (i18n "wireframe.inspector.layout.template_cant_fit")
          }}
          @action={{fn this.pick option.template}}
        >
          <span class="wireframe-template-menu__preview">
            <TemplatePreview @template={{option.template}} />
          </span>
          <span class="wireframe-template-menu__label">{{i18n
              (concat
                "wireframe.inspector.layout.templates." option.template.i18nKey
              )
            }}</span>
          {{#if option.isActive}}
            {{dIcon "check" class="wireframe-template-menu__check"}}
          {{/if}}
        </DButton>
      {{/each}}
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

// Maps a CSS keyword to its i18n-key fragment (`space-between` →
// `space_between`), since i18n keys can't contain hyphens.
function underscore(value) {
  return value.replace(/-/g, "_");
}
