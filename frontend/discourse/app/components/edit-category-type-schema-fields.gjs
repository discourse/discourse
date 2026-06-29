import Component from "@glimmer/component";
import { get, hash } from "@ember/helper";
import SettingDefinitionField from "discourse/components/setting-definition-field";
import { bind } from "discourse/lib/decorators";
import ComboBox from "discourse/select-kit/components/combo-box";
import { i18n } from "discourse-i18n";

export default class EditCategoryTypeSchemaFields extends Component {
  get schema() {
    return (
      this.args.category?.getType(this.args.categoryType)
        ?.configuration_schema ?? []
    );
  }

  get hasCustomFields() {
    return this.schema.category_custom_fields?.some((entry) =>
      this.isFieldVisible(entry)
    );
  }

  get hasCategorySettings() {
    return this.schema.category_settings?.some((entry) =>
      this.isFieldVisible(entry)
    );
  }

  get hasSiteTexts() {
    return this.schema.site_texts?.some((entry) => this.isFieldVisible(entry));
  }

  get className() {
    let classes = [
      "edit-category-type-schema-fields",
      `--category-type-${this.args.categoryType}`,
    ];
    if (this.args.active) {
      classes.push("active");
    }
    if (!this.hasCustomFields && !this.hasCategorySettings) {
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

  @bind
  dependencyMet(entry) {
    if (!entry.depends_on) {
      return true;
    }

    const data = this.args.transientData ?? {};
    const value =
      data.custom_fields?.[entry.depends_on] ??
      data.category_type_site_settings?.[entry.depends_on] ??
      data.category_type_settings?.[entry.depends_on];

    return value === true || value === "true";
  }

  @bind
  isFieldVisible(entry) {
    return this.shouldDisplayField(entry) && this.dependencyMet(entry);
  }

  <template>
    <div class={{this.className}}>
      {{#if this.hasCustomFields}}
        <@form.Section>
          <@form.Object @name="custom_fields" as |customFields|>
            {{#each this.schema.category_custom_fields as |entry|}}
              {{#if (this.isFieldVisible entry)}}
                <SettingDefinitionField
                  @definition={{entry}}
                  @form={{customFields}}
                />
              {{/if}}
            {{/each}}
          </@form.Object>
        </@form.Section>
      {{/if}}

      {{#if this.hasCategorySettings}}
        <@form.Section>
          <@form.Object @name="category_type_settings" as |categorySettings|>
            {{#each this.schema.category_settings as |entry|}}
              {{#if (this.isFieldVisible entry)}}
                <SettingDefinitionField
                  @definition={{entry}}
                  @form={{categorySettings}}
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
        {{#if this.hasSiteTexts}}
          <@form.Object @name="site_texts" as |siteTexts|>
            {{#each this.schema.site_texts as |entry|}}
              {{#if (this.isFieldVisible entry)}}
                <siteTexts.Field
                  @name={{entry.name}}
                  @type="input"
                  @title={{entry.label}}
                  @description={{entry.description}}
                  @disabled={{@isLoadingSiteTextsLocale}}
                  @labelFormat="full"
                  @format="large"
                  as |field|
                >
                  <div class="schema-site-text">
                    {{#if @availableLocales}}
                      <ComboBox
                        @valueProperty="value"
                        @content={{@availableLocales}}
                        @value={{@siteTextsLocale}}
                        @onChange={{@switchSiteTextsLocale}}
                        @options={{hash filterable=true}}
                        class="schema-site-text__locale"
                      />
                    {{/if}}
                    <field.Control />
                  </div>
                </siteTexts.Field>
              {{/if}}
            {{/each}}
          </@form.Object>
        {{/if}}

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
                      <SettingDefinitionField
                        @definition={{entry}}
                        @form={{siteSettings}}
                      />
                    {{/each}}
                  </div>
                </div>
              {{/if}}
            {{else}}
              {{#each group.entries as |entry|}}
                <SettingDefinitionField
                  @definition={{entry}}
                  @form={{siteSettings}}
                />
              {{/each}}
            {{/if}}
          {{/each}}
        </@form.Object>
      </@form.Emphasis>
    </div>
  </template>
}
