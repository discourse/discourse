import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { bind } from "discourse/lib/decorators";
import discourseLater from "discourse/lib/later";
import { eq } from "discourse/truth-helpers";

export default class UpsertCategorySupport extends Component {
  get schema() {
    return (
      this.args.category?.typeMetadata("support")?.configuration_schema ?? []
    );
  }

  @bind
  applyDefaults() {
    discourseLater(() => {
      for (const entry of this.schema) {
        if (
          entry.default !== undefined &&
          this.args.transientData?.[entry.key] === undefined
        ) {
          this.args.form.set(entry.key, entry.default);
        }
      }
    });
  }

  <template>
    <@form.Section
      class="edit-category-tab edit-category-tab-support
        {{if (eq @selectedTab 'support') 'active'}}"
      {{didInsert this.applyDefaults}}
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
