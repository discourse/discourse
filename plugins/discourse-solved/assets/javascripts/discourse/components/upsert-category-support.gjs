import Component from "@glimmer/component";
import { eq } from "discourse/truth-helpers";

export default class UpsertCategorySupport extends Component {
  constructor() {
    super(...arguments);
    this.applyDefaults();
  }

  get schema() {
    return this.args.category?.category_type_schema ?? [];
  }

  applyDefaults() {
    for (const entry of this.schema) {
      if (
        entry.default !== undefined &&
        this.args.transientData?.[entry.key] === undefined
      ) {
        this.args.form.set(entry.key, entry.default);
      }
    }
  }

  <template>
    <@form.Section
      class="edit-category-tab edit-category-tab-support
        {{if (eq @selectedTab 'support') 'active'}}"
    >
      {{#each this.schema as |entry|}}
        {{#if (eq entry.type "bool")}}
          <@form.Field
            @name={{entry.key}}
            @title={{entry.label}}
            @format="large"
            as |field|
          >
            <field.Checkbox />
          </@form.Field>
        {{else if (eq entry.type "integer")}}
          <@form.Field
            @name={{entry.key}}
            @title={{entry.label}}
            @format="large"
            as |field|
          >
            <field.Input @type="number" />
          </@form.Field>
        {{else}}
          <@form.Field
            @name={{entry.key}}
            @title={{entry.label}}
            @format="large"
            as |field|
          >
            <field.Input />
          </@form.Field>
        {{/if}}
      {{/each}}
    </@form.Section>
  </template>
}
