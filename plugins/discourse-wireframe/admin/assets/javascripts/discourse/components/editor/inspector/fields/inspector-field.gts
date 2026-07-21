// @ts-check
import { get } from "@ember/helper";
import { and, eq, not, or } from "discourse/truth-helpers";
import InspectorCategoryField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-category-field";
import InspectorDimensionField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-dimension-field";
import InspectorGroupField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-group-field";
import InspectorImageField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-image-field";
import InspectorRepeatableField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-repeatable-field";
import InspectorRichTextField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-rich-text-field";
import InspectorSegmentedField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-segmented-field";
import InspectorStepperField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-stepper-field";
import InspectorTagField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-tag-field";
import InspectorTopicField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-topic-field";
import InspectorUserField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-user-field";
import { toFlatMarkdown } from "discourse/plugins/discourse-wireframe/discourse/lib/rich-text";

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
  // `radio-group` and `segmented` are the same single-select enum picker — the
  // unified InspectorSegmentedField (icon segments with a dropdown fallback) —
  // so both ride the `custom` slot and render the same branch below.
  "radio-group": "custom",
  color: "color",
  icon: "icon",
  emoji: "emoji",
  // `image` rides FormKit's `custom` slot; the per-control branch below
  // renders the bespoke InspectorImageField that owns the full value
  // shape (`{ source, url, width?, height?, dark? }`).
  image: "custom",
  "rich-text": "composer",
  // `rich-inline` rides the `custom` slot: when the arg declares a schema
  // variant (`ui.schema`) the branch below mounts the editable inline
  // rich-text editor; otherwise it falls back to a read-only summary (the
  // canvas inline editor remains the other edit surface either way).
  "rich-inline": "custom",
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
  "topic-select": "custom",
  // An array of structured items (`itemType: "object"`). Rides the `custom`
  // slot; the bespoke control renders one editable row per item.
  repeatable: "custom",
  // Numeric controls and the segmented enum picker also ride the `custom`
  // slot; their per-control branches below mount the matching field component.
  dimension: "custom",
  stepper: "custom",
  segmented: "custom",
});

/**
 * Maps a `ui.control` to the FormKit field "type" value,
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
 *   @form              the FormKit form object; its `Field` component is
 *                      invoked for each field.
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
 *   @disabled          When true, the field renders read-only. Set for
 *                      unregistered blocks — the editor doesn't know their
 *                      schema, so their values are shown but not editable.
 */
const InspectorField = <template>
  <@form.Field
    @name={{@field.name}}
    @title={{@field.title}}
    @helpText={{@field.helpText}}
    @validation={{if @validationRuleFor (@validationRuleFor @field)}}
    @type={{fieldTypeFor @field.control}}
    @onSet={{@onFieldSet}}
    @disabled={{@disabled}}
    as |formField|
  >
    {{#if (eq @field.control "select")}}
      <formField.Control as |select|>
        {{#each @field.options as |option|}}
          <select.Option @value={{option}}>{{option}}</select.Option>
        {{/each}}
      </formField.Control>
    {{else if
      (or (eq @field.control "radio-group") (eq @field.control "segmented"))
    }}
      {{! Single-select enum. The unified field renders icon segments (with a
          tooltip per option) and falls back to a dropdown when the options
          don't fit a segmented row. Icons come from the arg's optionIcons map;
          the value doubles as the label / tooltip. }}
      <formField.Control>
        <InspectorSegmentedField
          @custom={{formField}}
          @options={{@field.options}}
          @optionIcons={{@field.optionIcons}}
        />
      </formField.Control>
    {{else if (eq @field.control "image")}}
      {{! Image args own a bespoke custom control with Upload or URL
          tabs, an optional dark variant, and a ratio-mismatch warning.
          Mounted inside the FormKit custom control slot (a styling
          wrapper that yields its content) — the inner component
          reads/writes the field value directly via the yielded
          form field. }}
      <formField.Control>
        <InspectorImageField @custom={{formField}} @schema={{@field.schema}} />
      </formField.Control>
    {{else if (eq @field.control "repeatable")}}
      {{! An array of structured items. The bespoke control reads/writes the
          whole array live via the wireframe service and renders one editable
          row per item, built from the arg's item schema. }}
      <formField.Control>
        <InspectorRepeatableField
          @custom={{formField}}
          @schema={{@field.schema}}
        />
      </formField.Control>
    {{else if (eq @field.control "category-select")}}
      {{! The custom-type FormKit control renders a styling wrapper that
          just yields its content (FKControlCustom doesn't yield the field —
          it's empty). The chooser binds value/set off the OUTER form field
          (the FieldData yielded by the form's Field component), matching the
          established pattern in app/components/tag-settings.gjs for the
          synonyms picker. }}
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
    {{else if (eq @field.control "topic-select")}}
      <formField.Control>
        <InspectorTopicField @custom={{formField}} />
      </formField.Control>
    {{else if (eq @field.control "dimension")}}
      {{! Numeric value with an optional unit selector and inline slider. Reads
          its configuration (units / step / slider / bounds) off the arg schema
          and writes through the yielded field. }}
      <formField.Control>
        <InspectorDimensionField
          @custom={{formField}}
          @schema={{@field.schema}}
        />
      </formField.Control>
    {{else if (eq @field.control "stepper")}}
      {{! Numeric value with decrement / increment buttons. }}
      <formField.Control>
        <InspectorStepperField
          @custom={{formField}}
          @schema={{@field.schema}}
        />
      </formField.Control>
    {{else if (eq @field.control "rich-inline")}}
      {{#if (and @field.schema.ui.schema (not @disabled))}}
        {{! Editable rich text editor (bold / italic / link), mounted in
            the inspector for headless editing. Reads the schema variant from
            the arg's ui.schema. }}
        <formField.Control>
          <InspectorRichTextField
            @custom={{formField}}
            @schema={{@field.schema.ui.schema}}
          />
        </formField.Control>
      {{else}}
        {{! Read-only summary — no schema variant declared, or the field is
            disabled. Flattens any marks to inline markdown so what they see
            here matches what they typed. }}
        <div class="wireframe-inspector-rich-inline">
          <span
            class="wireframe-inspector-rich-inline__summary"
          >{{toFlatMarkdown (get @values @field.name)}}</span>
          <span class="wireframe-inspector-rich-inline__hint">Edit on the canvas</span>
        </div>
      {{/if}}
    {{else}}
      <formField.Control placeholder={{@field.placeholder}} />
    {{/if}}
  </@form.Field>
</template>;

export default InspectorField;
