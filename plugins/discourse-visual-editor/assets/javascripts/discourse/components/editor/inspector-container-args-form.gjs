// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import { isFieldVisible, schemaToFields } from "../../lib/schema-to-fields";

/**
 * Maps `ui.control` to a FormKit `<form.Field @type>`. Kept in sync with
 * the parallel map in `InspectorForm` — the placement form supports the
 * same control set since both run schema fields through the same FormKit
 * pipeline.
 */
const FORM_KIT_TYPE_BY_CONTROL = {
  text: "input-text",
  number: "input-number",
  url: "input-url",
  textarea: "textarea",
  toggle: "toggle",
  select: "select",
  "radio-group": "radio-group",
};

/**
 * Inspector form for the selected entry's `containerArgs` — placement
 * hints the parent container reads (e.g. CSS Grid `column` / `row` when
 * the parent is a `ve:layout` in grid mode).
 *
 * Renders one collapsible section per top-level namespace declared in the
 * parent's `childArgs` schema. Each section is gated by its `ui.conditional`
 * predicate against the parent's `args` — so a `grid` section configured
 * with `conditional: { arg: "mode", equals: "grid" }` only appears when
 * the parent layout is actually in grid mode.
 *
 * Edits commit via `visualEditor.updateSelectedContainerArg(namespace, name,
 * value)`, which routes through `replaceEntryContainerArgs` as a structural
 * mutation. Placement edits are rare relative to typography, so the
 * keystroke-debounced path used for `args` isn't necessary here.
 */
export default class InspectorContainerArgsForm extends Component {
  @service visualEditor;

  get parentChildArgsSchema() {
    return this.visualEditor.selectedBlockData?.parentChildArgsSchema ?? null;
  }

  get parentArgs() {
    return this.visualEditor.selectedBlockData?.parentArgsSnapshot ?? {};
  }

  get containerArgsSnapshot() {
    return this.visualEditor.selectedBlockData?.containerArgsSnapshot ?? {};
  }

  /**
   * One entry per top-level namespace the parent declares, each with the
   * namespace label and the resolved set of nested fields. Namespaces
   * whose `ui.conditional` predicate fails against the parent's current
   * args are filtered out — the inspector only shows the section that
   * matches the parent's mode.
   */
  @cached
  get visibleNamespaces() {
    const schema = this.parentChildArgsSchema;
    if (!schema) {
      return [];
    }
    const sections = [];
    for (const [namespace, def] of Object.entries(schema)) {
      if (def?.type !== "object") {
        continue;
      }
      const conditional = def.ui?.conditional ?? null;
      if (conditional && !isFieldVisible({ conditional }, this.parentArgs)) {
        continue;
      }
      const fields = schemaToFields(def.properties ?? {});
      if (fields.length === 0) {
        continue;
      }
      sections.push({
        namespace,
        label: def.ui?.label ?? namespace,
        fields,
        values: this.containerArgsSnapshot[namespace] ?? def.default ?? {},
      });
    }
    return sections;
  }

  @action
  fieldType(control) {
    return FORM_KIT_TYPE_BY_CONTROL[control] ?? "input-text";
  }

  @action
  async onFieldSet(namespace, value, ctx) {
    await ctx.set(ctx.name, value);
    this.visualEditor.updateSelectedContainerArg(namespace, ctx.name, value);
  }

  <template>
    {{#each this.visibleNamespaces as |section|}}
      <Form
        @data={{section.values}}
        class="visual-editor-inspector-form visual-editor-inspector-container-args-form"
        as |form|
      >
        <form.Section @title={{section.label}}>
          {{#each section.fields as |field|}}
            <form.Field
              @name={{field.name}}
              @title={{field.title}}
              @description={{field.helpText}}
              @type={{this.fieldType field.control}}
              @onSet={{fn this.onFieldSet section.namespace}}
              as |formField|
            >
              {{#if (eq field.control "select")}}
                <formField.Control as |select|>
                  {{#each field.options as |option|}}
                    <select.Option @value={{option}}>{{option}}</select.Option>
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
      </Form>
    {{/each}}
  </template>
}
