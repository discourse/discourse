// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { isFieldVisible, schemaToFields } from "../../lib/schema-to-fields";
import InspectorField from "./inspector-field";

/**
 * Inspector form for the selected entry's `containerArgs` — placement
 * hints the parent container reads (e.g. CSS Grid `column` / `row` when
 * the parent is a `wf:layout` in grid mode).
 *
 * Renders one collapsible section per top-level namespace declared in the
 * parent's `childArgs` schema. Each section is gated by its `ui.conditional`
 * predicate against the parent's `args` — so a `grid` section configured
 * with `conditional: { arg: "mode", equals: "grid" }` only appears when
 * the parent layout is actually in grid mode.
 *
 * Edits commit via `wireframeEntryEdits.updateSelectedContainerArg(namespace,
 * name, value)`, which routes through `replaceEntryContainerArgs` as a
 * structural mutation. Placement edits are rare relative to typography, so the
 * keystroke-debounced path used for `args` isn't necessary here.
 */
export default class InspectorContainerArgsForm extends Component {
  @service wireframeEntryEdits;
  @service wireframeSelection;

  get parentChildArgsSchema() {
    return (
      this.wireframeSelection.selectedBlockData?.parentChildArgsSchema ?? null
    );
  }

  get parentArgs() {
    return this.wireframeSelection.selectedBlockData?.parentArgsSnapshot ?? {};
  }

  get containerArgsSnapshot() {
    return (
      this.wireframeSelection.selectedBlockData?.containerArgsSnapshot ?? {}
    );
  }

  /**
   * Whether the placement fields render read-only. True for unregistered
   * blocks: the editor doesn't know the block's schema, so none of its
   * values — placement hints included — are editable from the inspector.
   *
   * @returns {boolean}
   */
  get disabled() {
    return this.wireframeSelection.selectedBlockData?.isRegistered === false;
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
  async onFieldSet(namespace, value, ctx) {
    await ctx.set(ctx.name, value);
    this.wireframeEntryEdits.updateSelectedContainerArg(
      namespace,
      ctx.name,
      value
    );
  }

  <template>
    {{#each this.visibleNamespaces as |section|}}
      <Form
        @data={{section.values}}
        class="wireframe-inspector-form wireframe-inspector-container-args-form"
        as |form|
      >
        <form.Section @title={{section.label}}>
          {{#each section.fields as |field|}}
            <InspectorField
              @form={{form}}
              @field={{field}}
              @values={{section.values}}
              @onFieldSet={{fn this.onFieldSet section.namespace}}
              @disabled={{this.disabled}}
            />
          {{/each}}
        </form.Section>
      </Form>
    {{/each}}
  </template>
}
