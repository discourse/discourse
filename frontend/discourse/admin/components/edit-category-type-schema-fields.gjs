import Component from "@glimmer/component";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const SchemaFormField = <template>
  {{#if (eq @entry.type "bool")}}
    <@formObject.Field
      @name={{@entry.key}}
      @title={{@entry.label}}
      @helpText={{@entry.description}}
      @format="large"
      as |field|
    >
      <field.Checkbox />
    </@formObject.Field>
  {{else if (eq @entry.type "integer")}}
    <@formObject.Field
      @name={{@entry.key}}
      @title={{@entry.label}}
      @description={{@entry.description}}
      @format="large"
      as |field|
    >
      <field.Input @type="number" />
    </@formObject.Field>
  {{else}}
    <@formObject.Field
      @name={{@entry.key}}
      @title={{@entry.label}}
      @description={{@entry.description}}
      @format="large"
      as |field|
    >
      <field.Input />
    </@formObject.Field>
  {{/if}}
</template>;

export default class EditCategoryTypeSchemaFields extends Component {
  get schema() {
    return (
      this.args.category?.getType(this.args.categoryType)
        ?.configuration_schema ?? []
    );
  }

  get className() {
    let classes = ["edit-category-type-schema-fields"];
    classes.push(`--category-type-${this.args.categoryType}`);
    if (this.args.active) {
      classes.push(" active");
    }
    return classes.join(" ");
  }

  <template>
    <div class={{this.className}}>
      <@form.Section
        @title={{i18n "category.type_settings_schema.category_custom_fields"}}
      >
        <@form.Object @name="custom_fields" as |customFields|>
          {{#each this.schema.category_custom_fields as |entry|}}
            <SchemaFormField @entry={{entry}} @formObject={{customFields}} />
          {{/each}}
        </@form.Object>
      </@form.Section>

      <@form.Section
        @title={{i18n "category.type_settings_schema.site_settings"}}
      >
        <@form.Alert @type="danger">
          {{i18n "category.settings_apply_to_all_of_type_warning"}}
        </@form.Alert>
        <@form.Object @name="category_type_site_settings" as |siteSettings|>
          {{#each this.schema.site_settings as |entry|}}
            <SchemaFormField @entry={{entry}} @formObject={{siteSettings}} />
          {{/each}}
        </@form.Object>
      </@form.Section>
    </div>
  </template>
}
