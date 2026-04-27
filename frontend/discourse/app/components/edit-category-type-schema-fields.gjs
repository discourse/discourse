import Component from "@glimmer/component";
import { get } from "@ember/helper";
import RelativeTimePicker from "discourse/components/relative-time-picker";
import { bind } from "discourse/lib/decorators";
import { eq } from "discourse/truth-helpers";
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
      @format="full"
      @type="custom"
      as |field|
    >
      <RelativeTimePicker
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
      @format="full"
      @type="input-number"
      as |field|
    >
      <field.Control min={{@entry.min}} max={{@entry.max}} />
    </@formObject.Field>
  {{else}}
    <@formObject.Field
      @name={{@entry.key}}
      @type="input"
      @title={{@entry.label}}
      @description={{@entry.description}}
      @validation={{if @entry.required "required"}}
      @labelFormat="full"
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

  get hasCustomFields() {
    return this.schema.category_custom_fields?.some((entry) =>
      this.shouldDisplayField(entry)
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
    if (!this.hasCustomFields) {
      classes.push("--site-settings-only");
    }
    return classes.join(" ");
  }

  @bind
  groupEntries(entries) {
    const groups = [];
    const byDependsOn = new Map();

    entries?.forEach((entry) => {
      const dependsOn = entry.depends_on || null;
      let group = byDependsOn.get(dependsOn);
      if (!group) {
        group = { dependsOn, entries: [] };
        byDependsOn.set(dependsOn, group);
        groups.push(group);
      }
      group.entries.push(entry);
    });

    return groups;
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
      {{#if this.hasCustomFields}}
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
      {{/if}}

      {{yield to="beforeSiteSettings"}}

      <@form.Emphasis
        @title={{i18n "category.type_settings_schema.site_settings"}}
        @subtitle={{i18n "category.settings_apply_to_all_of_type_warning"}}
      >
        <@form.Object
          @name="category_type_site_settings"
          as |siteSettings data|
        >
          {{#each (this.groupEntries this.schema.site_settings) as |group|}}
            {{#if group.dependsOn}}
              {{#if (get data group.dependsOn)}}
                <div class="--dependent">
                  <div class="--dependent-border"></div>
                  <div class="--dependent-fields">
                    {{#each group.entries as |entry|}}
                      <SchemaFormField
                        @category={{@category}}
                        @entry={{entry}}
                        @formObject={{siteSettings}}
                      />
                    {{/each}}
                  </div>
                </div>
              {{/if}}
            {{else}}
              {{#each group.entries as |entry|}}
                <SchemaFormField
                  @category={{@category}}
                  @entry={{entry}}
                  @formObject={{siteSettings}}
                />
              {{/each}}
            {{/if}}
          {{/each}}
        </@form.Object>
      </@form.Emphasis>
    </div>
  </template>
}
