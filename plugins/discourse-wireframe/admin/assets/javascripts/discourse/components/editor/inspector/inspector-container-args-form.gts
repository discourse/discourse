import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import InspectorField from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/fields/inspector-field";
import {
  isFieldVisible,
  schemaToFields,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/schema-to-fields";
import type WireframeEntryConfigService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-entry-config";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

/** The inspector field descriptor produced by `schemaToFields`. */
type InspectorFieldDescriptor =
  import("discourse/plugins/discourse-wireframe/discourse/lib/layout/schema-to-fields").InspectorField;

/**
 * The context object FormKit hands a `@onSet` handler: the field's `name`
 * plus a `set` callback that writes the value into FormKit's own draft data.
 */
type FormFieldSetContext = {
  /** Name of the field being updated. */
  name: string;
  /** Writes a field into FormKit's draft data. */
  set: (
    /** Field name to update. */
    name: string,
    /** Replacement field value. */
    value: unknown
  ) => unknown;
};

/** One collapsible placement section, one per top-level parent namespace. */
type ContainerArgsSection = {
  /** Top-level container-argument namespace. */
  namespace: string;
  /** Human-readable namespace label. */
  label: string;
  /** Visible fields belonging to the namespace. */
  fields: InspectorFieldDescriptor[];
  /** Current namespace values keyed by field name. */
  values: Record<string, unknown>;
};

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
 * Edits commit via `wireframeEntryConfig.updateSelectedContainerArg(namespace,
 * name, value)`, which routes through `replaceEntryContainerArgs` as a
 * structural mutation. Placement edits are rare relative to typography, so the
 * keystroke-debounced path used for `args` isn't necessary here.
 */
export default class InspectorContainerArgsForm extends Component {
  @service declare wireframeEntryConfig: WireframeEntryConfigService;
  @service declare wireframeSelection: WireframeSelectionService;

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
  get visibleNamespaces(): ContainerArgsSection[] {
    const schema = this.parentChildArgsSchema;
    if (!schema) {
      return [];
    }
    const sections: ContainerArgsSection[] = [];
    for (const [namespace, def] of Object.entries(schema)) {
      if (def?.type !== "object") {
        continue;
      }
      const conditional = def.ui?.conditional ?? null;
      // `isFieldVisible` only inspects `.conditional`; the namespace gate has
      // no full field descriptor, so pass the minimal shape it reads.
      if (conditional && !isFieldVisible({ conditional }, this.parentArgs)) {
        continue;
      }
      const fields = schemaToFields(def.properties ?? {});
      if (fields.length === 0) {
        continue;
      }
      const values = this.containerArgsSnapshot[namespace] ?? def.default ?? {};
      sections.push({
        namespace,
        label: def.ui?.label ?? namespace,
        fields,
        values:
          typeof values === "object" &&
          values !== null &&
          !Array.isArray(values)
            ? { ...values }
            : {},
      });
    }
    return sections;
  }

  @action
  async onFieldSet(
    namespace: string,
    value: unknown,
    ctx: FormFieldSetContext
  ) {
    await ctx.set(ctx.name, value);
    this.wireframeEntryConfig.updateSelectedContainerArg(
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
