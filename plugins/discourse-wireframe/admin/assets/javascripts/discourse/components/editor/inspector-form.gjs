// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { friendlyErrorMessage } from "discourse/plugins/discourse-wireframe/discourse/lib/friendly-error-message";
import {
  buildValidationRule,
  groupFields,
  inferSchemaFromValues,
  isFieldVisible,
  schemaToFields,
} from "../../lib/schema-to-fields";
import InspectorField from "./inspector-field";

/**
 * Coerces a control's raw input value back into the type its schema
 * declared. HTML inputs (radio in particular) only carry strings, so
 * a number+enum arg like a heading's `level` would otherwise reach the
 * layout as a string and trip the args validator.
 *
 * Returns the value untouched when it's empty/null or when the schema
 * doesn't declare a coerce-able type — the caller handles deletion
 * semantics separately, and we don't want to manufacture `NaN` from a
 * deliberately-empty value.
 *
 * @param {*} value
 * @param {{type?: string, integer?: boolean}|undefined} argDef
 * @returns {*}
 */
function coerceToSchemaType(value, argDef) {
  if (!argDef || typeof value !== "string" || value === "") {
    return value;
  }
  if (argDef.type === "number") {
    return argDef.integer ? parseInt(value, 10) : parseFloat(value);
  }
  if (argDef.type === "boolean") {
    return value === "true";
  }
  return value;
}

/**
 * Inspector form for the selected block's args. Reads the args schema
 * (with `ui` hints), maps it to FormKit fields via `schemaToFields`,
 * and pushes value changes back through `wireframe.updateSelectedArg`.
 *
 * Live editing is wired through each Field's `@onSet` hook: when a control
 * commits a new value, FormKit invokes `onSet(value, { set, name })` instead
 * of its default internal setter. We call both — `set(name, value)` keeps
 * FormKit's own draft data in sync, and `updateSelectedArg(name, value)`
 * pushes the change to the layout so the canvas re-renders. (FormKit
 * intentionally has no form-level `@onChange`; per-field `@onSet` is the
 * supported extension point — see `fk/field-data.gjs:71`.)
 */
export default class InspectorForm extends Component {
  @service wireframeArgEdit;
  @service wireframeSelection;

  /**
   * FormKit API exposed via `<Form @onRegisterApi>`. Used to push the
   * blocks-API's structured validation errors into FormKit's per-field
   * error slot (`addError`), so each failing arg renders with FormKit's
   * native red border + triangle-exclamation + message under the input.
   *
   * Plain field (not `@tracked`) — the sync side-effect runs from
   * `{{didInsert}}` / `{{didUpdate}}` modifiers driven by the
   * `errorSyncKey` getter, which IS tracked. We never read this field
   * from the template.
   *
   * @type {{addError: Function, removeErrors: Function}|null}
   */
  #formApi = null;

  /**
   * Subscribes the surrounding tracking frame to the wireframe service's
   * structured field-errors map. Used as the dependency argument to the
   * `{{didUpdate}}` modifier so the FormKit sync re-runs whenever the
   * validator's stamps change (an arg edit clears stamps, a republish
   * re-runs validation and may add new ones).
   *
   * Returns the map itself so we can iterate it inside the sync method
   * without taking a second tracked dep.
   *
   * @returns {Object<string, Array<Object>>}
   */
  @cached
  get fieldErrors() {
    return this.wireframeSelection.selectedBlockFieldErrors;
  }

  /**
   * The block's args schema for the current selection. We prefer the
   * schema the block declared in `@block(...)`, but fall back to inferring
   * one from the live arg values when the block didn't declare any. The
   * fallback gives us editable text/number/toggle fields keyed by whatever
   * the layout actually passes, even for blocks that haven't been migrated
   * to declare a schema.
   */
  get schema() {
    const declared = this.wireframeSelection.selectedBlockData?.metadata?.args;
    if (declared && Object.keys(declared).length > 0) {
      return declared;
    }
    return inferSchemaFromValues(this.values);
  }

  @cached
  get fieldGroups() {
    return groupFields(schemaToFields(this.schema));
  }

  /**
   * Whether the form's fields render read-only. True for unregistered
   * blocks: the editor doesn't know their schema, so we surface the live
   * values but disallow edits we couldn't validate. The schema here is
   * inferred from the values, which is exactly why it can't be trusted as
   * an editable contract.
   *
   * @returns {boolean}
   */
  get disabled() {
    return this.wireframeSelection.selectedBlockData?.isRegistered === false;
  }

  /**
   * The lock state when the current selection is a composite part: `"all"`
   * (the whole part is locked), a Set of locked arg names, or `null` (not a
   * part, or nothing locked). Locked args render disabled in the form, since
   * a locked arg can't be overridden in place — only after detaching.
   *
   * @returns {"all"|Set<string>|null}
   */
  get lockedArgs() {
    const lock = this.wireframeSelection.partLockForSelection();
    if (lock === true) {
      return "all";
    }
    if (Array.isArray(lock)) {
      return new Set(lock);
    }
    return null;
  }

  /**
   * The seed args we hand to `<Form @data>`. We use the
   * `argsSnapshot` captured once at selection time (a plain object) rather
   * than spreading the live `entry.args` trackedObject on every read —
   * spreading a trackedObject opens tracked deps on every property, so
   * mutations would invalidate this getter and cascade through Form's
   * render path. Form takes the snapshot once at construction; FKFormData
   * is the source of truth for the inputs from there on.
   *
   * Image args carry the full value shape end-to-end (the custom
   * InspectorImageField reads/writes it directly), so no projection is
   * required here — the snapshot reaches FormKit verbatim.
   */
  get values() {
    return this.wireframeSelection.selectedBlockData?.argsSnapshot ?? {};
  }

  /**
   * Decorated with `@action` so Glimmer template subexpressions like
   * `(this.visibleFields group.fields)` keep the correct `this` binding.
   * Without it Glimmer extracts the bare function reference and calls it
   * without context, which throws when the body reads `this.values`.
   */
  @action
  visibleFields(fields) {
    const visible = fields.filter((field) =>
      isFieldVisible(field, this.values)
    );
    const locked = this.lockedArgs;
    if (!locked) {
      return visible;
    }
    // Annotate locked fields with a hint so the disabled control reads as
    // "locked by the composite" rather than mysteriously inert.
    const hint = i18n("wireframe.inspector.locked_field_hint");
    return visible.map((field) =>
      locked === "all" || locked.has(field.name)
        ? {
            ...field,
            helpText: field.helpText ? `${field.helpText} ${hint}` : hint,
          }
        : field
    );
  }

  /**
   * Whether a given field renders disabled: either the whole form is
   * read-only (unregistered block) or the field's arg is locked for the
   * selected composite part.
   *
   * @param {import("../../lib/schema-to-fields").InspectorField} field
   * @returns {boolean}
   */
  @action
  isFieldDisabled(field) {
    if (this.disabled) {
      return true;
    }
    const locked = this.lockedArgs;
    return locked === "all" || !!locked?.has(field.name);
  }

  /**
   * Builds the FormKit `@validation` rule string for a field from the
   * schema's `required` / `min` / `max` / `minLength` / `maxLength`
   * declarations. Returning `undefined` lets us omit the prop when the
   * schema declares no constraints — keeps Form's tree shallow.
   *
   * @param {import("../../lib/schema-to-fields").InspectorField} field
   * @returns {string|undefined}
   */
  @action
  validationRuleFor(field) {
    return buildValidationRule(field);
  }

  /**
   * Per-field `@onSet` handler. FormKit calls this with the new value plus
   * a context object whose `set` callback applies the value to FormKit's
   * own draft data. We invoke both: `set` keeps the form responsive and
   * the inputs in sync; `updateSelectedArg` pushes the change to the
   * editor service so the canvas re-renders with the new args.
   */
  @action
  async onFieldSet(value, ctx) {
    const argDef = this.schema?.[ctx.name];
    // Radio inputs hand their selected value back as a string (HTML
    // `<input>` values can't be anything else). For args whose schema
    // declares a non-string type, coerce the raw input back to that
    // type before forwarding to the editor service — otherwise the
    // validator rejects the layout ("Arg level must be a number, got
    // string") and the canvas falls out of sync with the draft.
    const coerced = coerceToSchemaType(value, argDef);

    // Treat empty string as absence for string args that don't declare a
    // default. Without this, the editor service writes the literal `""`
    // back into `entry.args` (per `writeArgs`'s "`""` is a valid scalar"
    // contract) and runtime `required` / `atLeastOne` / `allOrNone`
    // checks pass even though the field is visibly blank. Args WITH a
    // default keep the existing behaviour: clearing the field stores
    // `""` so the user's explicit empty overrides the default — matches
    // the inline-text editor's same convention in
    // `inline-edit-state.js:344-356`.
    const writeValue =
      coerced === "" && argDef?.default === undefined ? null : coerced;

    await ctx.set(ctx.name, coerced);
    this.wireframeArgEdit.updateSelectedArg(ctx.name, writeValue);
  }

  /**
   * Stashes FormKit's external-error API exposed by `<Form @onRegisterApi>`.
   * Called once when the Form mounts; the sync side-effect runs from
   * `{{didInsert}}` immediately after.
   *
   * @param {{addError: Function, removeErrors: Function}} api
   */
  @action
  registerFormApi(api) {
    this.#formApi = api;
  }

  /**
   * Pushes the wireframe service's structured validation errors into
   * FormKit. FormKit then renders each one under its matching field
   * (red border + triangle-exclamation + message under the input) AND
   * lists them in the form-level `<FKErrorsSummary>` it auto-mounts at
   * the top of the form. The summary uses the `title` we pass — which
   * is the arg's `ui.label` when declared — so users see "Button link"
   * instead of the raw arg name `ctaHref`.
   *
   * Called on mount (via `{{didInsert}}`) and whenever `fieldErrors`
   * changes (via `{{didUpdate}}`).
   *
   * Non-field errors (constraint violations, structural problems —
   * anything without a `field` on the structured detail) are routed
   * through synthetic `_block:<n>` keys. They never collide with real
   * arg names (real args can't start with `_`, see
   * `frontend/discourse/app/lib/blocks/-internals/validation/args.js`
   * `isReservedArgName`). We add them WITHOUT a title, so FormKit's
   * summary renders them as form-level errors — the message on its own,
   * with no field-focus link or label prefix (the constraint message,
   * e.g. "Set at least one of: …", is already self-describing).
   */
  @action
  syncErrors() {
    if (!this.#formApi) {
      return;
    }
    this.#formApi.removeErrors();

    // For an unregistered block the panel-level notice already explains the
    // single relevant problem (the block isn't registered), so we don't also
    // surface the validation error in the form's summary — that would show the
    // same fact twice. Validation itself is untouched; we just don't re-display
    // it here.
    if (this.disabled) {
      return;
    }

    for (const [field, details] of Object.entries(this.fieldErrors)) {
      const label = this.schema?.[field]?.ui?.label ?? field;
      for (const d of details) {
        this.#formApi.addError(field, {
          title: label,
          message: friendlyErrorMessage(d),
        });
      }
    }

    this.wireframeSelection.selectedBlockNonFieldErrors.forEach((d, i) => {
      this.#formApi.addError(`_block:${i}`, {
        message: friendlyErrorMessage(d),
      });
    });
  }

  <template>
    {{#if this.fieldGroups.length}}
      <div
        class="wireframe-inspector-form-host"
        {{didInsert this.syncErrors}}
        {{didUpdate this.syncErrors this.fieldErrors}}
      >
        <Form
          @data={{this.values}}
          @onRegisterApi={{this.registerFormApi}}
          class="wireframe-inspector-form"
          as |form|
        >
          {{#each this.fieldGroups as |group|}}
            {{#if (eq group.group "Advanced")}}
              {{! Native <details> for the magic "Advanced" group:
                collapsed by default, no JS state, accessible. Block
                authors opt in by setting `ui.group: "Advanced"` on
                rarely-touched args. Matches the disclosure pattern
                in `inspector-layout-form.gjs` (Advanced Templates). }}

              <details class="wireframe-inspector-form__advanced">
                <summary>{{group.group}}</summary>
                <div class="wireframe-inspector-form__advanced-body">
                  {{#each (this.visibleFields group.fields) as |field|}}
                    <InspectorField
                      @form={{form}}
                      @field={{field}}
                      @values={{this.values}}
                      @validationRuleFor={{this.validationRuleFor}}
                      @onFieldSet={{this.onFieldSet}}
                      @disabled={{this.isFieldDisabled field}}
                    />
                  {{/each}}
                </div>
              </details>
            {{else}}
              <form.Section @title={{group.group}}>
                {{#each (this.visibleFields group.fields) as |field|}}
                  <InspectorField
                    @form={{form}}
                    @field={{field}}
                    @values={{this.values}}
                    @validationRuleFor={{this.validationRuleFor}}
                    @onFieldSet={{this.onFieldSet}}
                    @disabled={{this.isFieldDisabled field}}
                  />
                {{/each}}
              </form.Section>
            {{/if}}
          {{/each}}
        </Form>
      </div>
    {{/if}}
  </template>
}
