// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import {
  buildValidationRule,
  groupFields,
  inferSchemaFromValues,
  isFieldVisible,
  schemaToFields,
} from "../../lib/schema-to-fields";
import InspectorField from "./inspector-field";
import InspectorValidationBanner from "./inspector-validation-banner";

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
 * Phase 2 inspector form. Reads the selected block's args schema (with `ui`
 * hints), maps it to FormKit fields via `schemaToFields`, and pushes value
 * changes back through `wireframe.updateSelectedArg`.
 *
 * Live editing is wired through each Field's `@onSet` hook: when a control
 * commits a new value, FormKit invokes `onSet(value, { set, name })` instead
 * of its default internal setter. We call both — `set(name, value)` keeps
 * FormKit's own draft data in sync, and `updateSelectedArg(name, value)`
 * pushes the change to the layout so the canvas re-renders. (FormKit
 * intentionally has no form-level `@onChange`; per-field `@onSet` is the
 * supported extension point — see `field-data.gjs:69`.)
 *
 * Phase 2 control coverage falls back to `input-text` for the entity pickers
 * (`category-select`, `tag-select`, `user-select`, `group-select`) until the
 * bespoke pickers ship in a later phase.
 */
export default class InspectorForm extends Component {
  @service wireframe;

  /**
   * The block's args schema for the current selection. We prefer the
   * schema the block declared in `@block(...)`, but fall back to inferring
   * one from the live arg values when the block didn't declare any. The
   * fallback gives us editable text/number/toggle fields keyed by whatever
   * the layout actually passes, even for blocks that haven't been migrated
   * to declare a schema.
   */
  get schema() {
    const declared = this.wireframe.selectedBlockData?.metadata?.args;
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
   * The seed args we hand to `<Form @data>`. We use the
   * `argsSnapshot` captured once at selection time (a plain object) rather
   * than spreading the live `entry.args` trackedObject on every read —
   * spreading a trackedObject opens tracked deps on every property, so
   * mutations would invalidate this getter and cascade through Form's
   * render path. Form takes the snapshot once at construction; FKFormData
   * is the source of truth for the inputs from there on.
   *
   * Image-upload args are stored in the layout as the full upload object
   * (`{ url, width, height, ... }`) so `DLightDarkImg` can render them
   * without an extra lookup. FormKit's `FKControlImage` (and the
   * `UppyImageUploader` it wraps), however, expects the field value to
   * be a URL string. Project just the `url` for FormKit's view; the
   * layout keeps the rich object via the dedicated `@onSet` handler
   * (`onFieldSet`).
   */
  get values() {
    const raw = this.wireframe.selectedBlockData?.argsSnapshot ?? {};
    const schema = this.schema;
    if (!schema) {
      return raw;
    }
    let projected = null;
    for (const [name, def] of Object.entries(schema)) {
      if (def?.ui?.control !== "image-upload") {
        continue;
      }
      const value = raw[name];
      if (value && typeof value === "object" && value.url) {
        projected ??= { ...raw };
        projected[name] = value.url;
      }
    }
    return projected ?? raw;
  }

  /**
   * Decorated with `@action` so Glimmer template subexpressions like
   * `(this.visibleFields group.fields)` keep the correct `this` binding.
   * Without it Glimmer extracts the bare function reference and calls it
   * without context, which throws when the body reads `this.values`.
   */
  @action
  visibleFields(fields) {
    return fields.filter((field) => isFieldVisible(field, this.values));
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
   *
   * For image-upload args we split the projection: FormKit's draft gets
   * the URL string so `UppyImageUploader` can paint its preview, while
   * the layout stores the full upload object (`{ url, width, height, ... }`)
   * that downstream renderers like `DLightDarkImg` consume. The full
   * object reaches us here because `FKControlImage.setImage` forwards
   * `UppyImageUploader.onUploadDone`'s payload verbatim.
   */
  @action
  async onFieldSet(value, ctx) {
    const argDef = this.schema?.[ctx.name];
    const isImageUpload = argDef?.ui?.control === "image-upload";
    // Radio inputs hand their selected value back as a string (HTML
    // `<input>` values can't be anything else). For args whose schema
    // declares a non-string type, coerce the raw input back to that
    // type before forwarding to the editor service — otherwise the
    // validator rejects the layout ("Arg level must be a number, got
    // string") and the canvas falls out of sync with the draft.
    const coerced = coerceToSchemaType(value, argDef);
    const formValue =
      isImageUpload && coerced && typeof coerced === "object"
        ? coerced.url
        : coerced;

    // Treat empty string as absence for string args that don't declare a
    // default. Without this, the editor service writes the literal `""`
    // back into `entry.args` (per `_writeArgs`'s "`""` is a valid scalar"
    // contract) and runtime `required` / `atLeastOne` / `allOrNone`
    // checks pass even though the field is visibly blank. Args WITH a
    // default keep the existing behaviour: clearing the field stores
    // `""` so the user's explicit empty overrides the default — matches
    // the inline-text editor's same convention in
    // `inline-edit-state.js:344-356`.
    const writeValue =
      coerced === "" && argDef?.default === undefined ? null : coerced;

    await ctx.set(ctx.name, formValue);
    this.wireframe.updateSelectedArg(ctx.name, writeValue);
  }

  <template>
    <InspectorValidationBanner />
    {{#if this.fieldGroups.length}}
      <Form @data={{this.values}} class="wireframe-inspector-form" as |form|>
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
                />
              {{/each}}
            </form.Section>
          {{/if}}
        {{/each}}
      </Form>
    {{/if}}
  </template>
}
