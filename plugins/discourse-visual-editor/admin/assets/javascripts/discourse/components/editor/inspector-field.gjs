// @ts-check
import { get } from "@ember/helper";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { toFlatMarkdown } from "discourse/plugins/discourse-visual-editor/discourse/lib/inline-rich-text";
import InspectorCategoryField from "./inspector-category-field";
import InspectorGroupField from "./inspector-group-field";
import InspectorTagField from "./inspector-tag-field";
import InspectorUserField from "./inspector-user-field";

/**
 * Single source of truth for the `ui.control` → FormKit `@type`
 * mapping. Both the main `InspectorForm` (block args) and
 * `InspectorContainerArgsForm` (placement / containerArgs) consume
 * this so the two never drift on which controls are supported.
 *
 * Source of truth for the supported FormKit control set is its own
 * `resolveFieldControl` (`frontend/discourse/app/form-kit/lib/field-control.js`).
 * Entity pickers (category / tag / user / group) ride FormKit's
 * `custom` slot; the renderer below wires the matching select-kit
 * chooser inline.
 */
export const FORM_KIT_TYPE_BY_CONTROL = Object.freeze({
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
  // `rich-inline` is read-only in the inspector — editing happens on the
  // canvas via the InlineEditController. The fallback FormKit type
  // (`input-text`) is unused because the template renders a bespoke
  // read-only branch instead.
  "rich-inline": "input-text",
  code: "code",
  "tag-chooser": "tag-chooser",
  // Entity pickers ride FormKit's `custom` slot: the template's
  // per-control branches render the matching select-kit chooser
  // inline (CategoryChooser / MiniTagChooser / etc.) and route value
  // changes through the consumer's `onFieldSet` just like every other
  // control.
  "category-select": "custom",
  "tag-select": "custom",
  "user-select": "custom",
  "group-select": "custom",
});

/**
 * Maps a `ui.control` to the FormKit `<form.Field @type="...">` value,
 * defaulting to `"input-text"` for anything not in the map.
 *
 * @param {string} control
 * @returns {string}
 */
export function fieldTypeFor(control) {
  return FORM_KIT_TYPE_BY_CONTROL[control] ?? "input-text";
}

/**
 * Shared inspector-field renderer. Used by both the main inspector
 * form (block args) and the container-args inspector (placement
 * hints). Centralising it here means the per-control branches —
 * radio-group icons, image-upload, entity pickers, rich-inline
 * read-only summary — can't fall out of sync the way they did when
 * each form maintained its own local template.
 *
 * Args contract:
 *
 *   @form              the `<Form @data>` yield (used for `<@form.Field>`).
 *   @field             the InspectorField descriptor from `schemaToFields`.
 *   @values            current values map (only the `rich-inline` branch
 *                      reads it, for the read-only summary).
 *   @validationRuleFor optional fn(field) → FormKit validation rule
 *                      string. Pass `undefined` to skip validation
 *                      (container-args form does this — its placement
 *                      schema doesn't declare required/min/max).
 *   @onFieldSet        FormKit `@onSet` handler; called with (value, ctx).
 *                      The container-args form curries its namespace in
 *                      via `(fn this.onFieldSet section.namespace)`, so
 *                      the shape stays identical here.
 */
const InspectorField = <template>
  <@form.Field
    @name={{@field.name}}
    @title={{@field.title}}
    @helpText={{@field.helpText}}
    @validation={{if @validationRuleFor (@validationRuleFor @field)}}
    @type={{fieldTypeFor @field.control}}
    @onSet={{@onFieldSet}}
    as |formField|
  >
    {{#if (eq @field.control "select")}}
      <formField.Control as |select|>
        {{#each @field.options as |option|}}
          <select.Option @value={{option}}>{{option}}</select.Option>
        {{/each}}
      </formField.Control>
    {{else if (eq @field.control "radio-group")}}
      <formField.Control as |radio|>
        {{#each @field.options as |option|}}
          <radio.Radio @value={{option}} aria-label={{option}}>
            {{#if @field.optionIcons}}
              {{#let (get @field.optionIcons option) as |icon|}}
                {{#if icon}}
                  <span title={{option}}>{{dIcon icon}}</span>
                {{else}}
                  {{option}}
                {{/if}}
              {{/let}}
            {{else}}
              {{option}}
            {{/if}}
          </radio.Radio>
        {{/each}}
      </formField.Control>
    {{else if (eq @field.control "image-upload")}}
      {{! FKControlImage forwards @type to UppyImageUploader, which
          requires a non-empty value (used as the MessageBus channel
          and the upload-type tag). "composer" is the generic
          catch-all type used elsewhere for free-form image uploads. }}
      <formField.Control @type="composer" />
    {{else if (eq @field.control "category-select")}}
      {{! `<formField.Control>` with `@type="custom"` renders a styling
          wrapper that just yields its content (`FKControlCustom` doesn't
          yield the field — it's empty). The chooser binds value/set off
          the OUTER `formField` (the FieldData yielded by `<form.Field>`),
          matching the established pattern in `app/components/tag-settings.gjs`
          for the synonyms picker. }}
      <formField.Control>
        <InspectorCategoryField
          @custom={{formField}}
          @schema={{@field.schema}}
        />
      </formField.Control>
    {{else if (eq @field.control "tag-select")}}
      <formField.Control>
        <InspectorTagField @custom={{formField}} />
      </formField.Control>
    {{else if (eq @field.control "user-select")}}
      <formField.Control>
        <InspectorUserField @custom={{formField}} />
      </formField.Control>
    {{else if (eq @field.control "group-select")}}
      <formField.Control>
        <InspectorGroupField @custom={{formField}} />
      </formField.Control>
    {{else if (eq @field.control "rich-inline")}}
      {{! Read-only summary — authors edit this arg on the canvas.
          Flattens any marks to inline markdown so what they see
          here matches what they typed. }}
      <div class="visual-editor-inspector-rich-inline">
        <span
          class="visual-editor-inspector-rich-inline__summary"
        >{{toFlatMarkdown (get @values @field.name)}}</span>
        <span class="visual-editor-inspector-rich-inline__hint">Edit on the
          canvas</span>
      </div>
    {{else}}
      <formField.Control placeholder={{@field.placeholder}} />
    {{/if}}
  </@form.Field>
</template>;

export default InspectorField;
