import Component from "@glimmer/component";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpsertCategorySupport extends Component {
  get schema() {
    return (
      this.args.category?.typeMetadata("support")?.configuration_schema ?? []
    );
  }

  <template>
    <div
      class="edit-category-tab edit-category-tab-support
        {{if (eq @selectedTab 'support') 'active'}}"
    >
      <@form.Section
        @title={{i18n "category.type_settings_schema.site_settings"}}
      >

        {{#each this.schema.site_settings as |entry|}}
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

      <@form.Section
        @title={{i18n "category.type_settings_schema.category_custom_fields"}}
      >
        <@form.Object @name="custom_fields" as |customFields|>
          {{#each this.schema.category_custom_fields as |entry|}}
            {{#if (eq entry.type "bool")}}
              <customFields.Field
                @name={{entry.key}}
                @title={{entry.label}}
                @format="large"
                as |field|
              >
                <field.Checkbox />
              </customFields.Field>
            {{else if (eq entry.type "integer")}}
              <customFields.Field
                @name={{entry.key}}
                @title={{entry.label}}
                @format="large"
                as |field|
              >
                <field.Input @type="number" />
              </customFields.Field>
            {{else}}
              <customFields.Field
                @name={{entry.key}}
                @title={{entry.label}}
                @format="large"
                as |field|
              >
                <field.Input />
              </customFields.Field>
            {{/if}}
          {{/each}}
        </@form.Object>
      </@form.Section>
    </div>
  </template>
}
