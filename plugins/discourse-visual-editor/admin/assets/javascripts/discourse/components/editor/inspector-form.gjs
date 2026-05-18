// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import {
  groupFields,
  inferSchemaFromValues,
  isFieldVisible,
  schemaToFields,
} from "../../lib/schema-to-fields";

/**
 * Maps our `ui.control` names to a `<form.Field @type="...">` value FormKit
 * accepts. The `input-*` prefix forwards to FKControlInput with the matching
 * HTML input type. Anything FormKit doesn't have a dedicated control for
 * (icon picker, image upload, entity pickers) falls back to `input-text` for
 * Phase 2 — we'll wire the bespoke pickers when we build them in later phases.
 *
 * Source of truth for the supported control set is FormKit's
 * `resolveFieldControl` (`frontend/discourse/app/form-kit/lib/field-control.js`).
 */
const FORM_KIT_TYPE_BY_CONTROL = {
  text: "input-text",
  number: "input-number",
  url: "input-url",
  textarea: "textarea",
  toggle: "toggle",
  select: "select",
  "radio-group": "radio-group",
  color: "color",
  icon: "icon",
  emoji: "emoji",
  "image-upload": "image",
  "rich-text": "composer",
  code: "code",
  "tag-chooser": "tag-chooser",
  // Entity pickers don't have FormKit controls yet; fall back to text for now.
  "category-select": "input-text",
  "tag-select": "input-text",
  "user-select": "input-text",
  "group-select": "input-text",
};

/**
 * Phase 2 inspector form. Reads the selected block's args schema (with `ui`
 * hints), maps it to FormKit fields via `schemaToFields`, and pushes value
 * changes back through `visualEditor.updateSelectedArg`.
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
  @service visualEditor;

  /**
   * The block's args schema for the current selection. We prefer the
   * schema the block declared in `@block(...)`, but fall back to inferring
   * one from the live arg values when the block didn't declare any. The
   * fallback gives us editable text/number/toggle fields keyed by whatever
   * the layout actually passes, even for blocks that haven't been migrated
   * to declare a schema.
   */
  get schema() {
    const declared = this.visualEditor.selectedBlockData?.metadata?.args;
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
   */
  get values() {
    return this.visualEditor.selectedBlockData?.argsSnapshot ?? {};
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

  @action
  fieldType(control) {
    return FORM_KIT_TYPE_BY_CONTROL[control] ?? "input-text";
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
    await ctx.set(ctx.name, value);
    this.visualEditor.updateSelectedArg(ctx.name, value);
  }

  <template>
    {{#if this.fieldGroups.length}}
      <Form
        @data={{this.values}}
        class="visual-editor-inspector-form"
        as |form|
      >
        {{#each this.fieldGroups as |group|}}
          <form.Section @title={{group.group}}>
            {{#each (this.visibleFields group.fields) as |field|}}
              <form.Field
                @name={{field.name}}
                @title={{field.title}}
                @description={{field.helpText}}
                @type={{this.fieldType field.control}}
                @onSet={{this.onFieldSet}}
                as |formField|
              >
                {{#if (eq field.control "select")}}
                  <formField.Control as |select|>
                    {{#each field.options as |option|}}
                      <select.Option
                        @value={{option}}
                      >{{option}}</select.Option>
                    {{/each}}
                  </formField.Control>
                {{else if (eq field.control "radio-group")}}
                  <formField.Control as |radio|>
                    {{#each field.options as |option|}}
                      <radio.Radio @value={{option}}>{{option}}</radio.Radio>
                    {{/each}}
                  </formField.Control>
                {{else}}
                  <formField.Control placeholder={{field.placeholder}} />
                {{/if}}
              </form.Field>
            {{/each}}
          </form.Section>
        {{/each}}
      </Form>
    {{/if}}
  </template>
}
