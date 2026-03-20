import Component from "@glimmer/component";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
import DRelativeTimePicker from "discourse/ui-kit/d-relative-time-picker";
import { i18n } from "discourse-i18n";

// NOTE: In future we may want to use FormKit versions of site setting components
// here rather than this custom implementation. We are also only supporting a small
// subset of site setting types / category field types for now, we can expand this as
// needed.
const SchemaFormField = <template>
  {{#if (eq @entry.type "bool")}}
    <@formObject.Field
      @name={{@entry.key}}
      @type="checkbox"
      @title={{@entry.label}}
      @validation={{if @entry.required "required"}}
      @format="full"
      @showTitle={{false}}
      as |field|
    >
      <field.Control>{{@entry.description}}</field.Control>
    </@formObject.Field>
  {{else if (eq @entry.subtype "duration")}}
    <@formObject.Field
      @name={{@entry.key}}
      @title={{@entry.label}}
      @description={{@entry.description}}
      @validation={{if @entry.required "required"}}
      @titleFormat="full"
      @descriptionFormat="full"
      @format="full"
      @type="custom"
      as |field|
    >
      <DRelativeTimePicker
        @durationHours={{field.value}}
        @durationOutputUnit="hours"
        @onChange={{field.set}}
      />
    </@formObject.Field>
  {{else if (eq @entry.type "integer")}}
    <@formObject.Field
      @name={{@entry.key}}
      @title={{@entry.label}}
      @description={{@entry.description}}
      @validation={{if @entry.required "required"}}
      @titleFormat="full"
      @descriptionFormat="full"
      @format="full"
      @type="input-number"
      as |field|
    >
      <field.Control />
    </@formObject.Field>
  {{else}}
    <@formObject.Field
      @name={{@entry.key}}
      @type="input"
      @title={{@entry.label}}
      @description={{@entry.description}}
      @validation={{if @entry.required "required"}}
      @titleFormat="full"
      @descriptionFormat="full"
      @format="large"
      as |field|
    >
      <field.Control />
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
    let classes = [
      "edit-category-type-schema-fields",
      `--category-type-${this.args.categoryType}`,
    ];
    if (this.args.active) {
      classes.push("active");
    }
    return classes.join(" ");
  }

  @bind
  shouldDisplayField(entry) {
    if (this.args.category.isCreated) {
      return entry.show_on_edit;
    }

    return entry.show_on_create;
  }

  <template>
    <div class={{this.className}}>
      <@form.Section>
        <@form.Object @name="custom_fields" as |customFields|>
          {{#each this.schema.category_custom_fields as |entry|}}
            {{#if (this.shouldDisplayField entry)}}
              <SchemaFormField
                @category={{@category}}
                @entry={{entry}}
                @formObject={{customFields}}
              />
            {{/if}}
          {{/each}}
        </@form.Object>
      </@form.Section>

      {{yield to="beforeSiteSettings"}}

      <@form.Emphasis
        @title={{i18n "category.type_settings_schema.site_settings"}}
        @subtitle={{i18n "category.settings_apply_to_all_of_type_warning"}}
      >
        <@form.Object @name="category_type_site_settings" as |siteSettings|>
          {{#each this.schema.site_settings as |entry|}}
            <SchemaFormField
              @category={{@category}}
              @entry={{entry}}
              @formObject={{siteSettings}}
            />
          {{/each}}
        </@form.Object>
      </@form.Emphasis>
    </div>
  </template>
}
