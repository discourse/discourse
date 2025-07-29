import { fn, hash } from "@ember/helper";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { i18n } from "discourse-i18n";

export default class EditCategoryLocalizations extends buildCategoryPanel(
  "localizations"
) {
  @service siteSettings;
  @service languageNameLookup;

  get availableLocales() {
    return this.siteSettings.available_content_localization_locales.map(
      ({ value }) => ({
        name: this.languageNameLookup.getLanguageName(value),
        value,
      })
    );
  }

  <template>
    {{#if (eq @transientData.localizations.length 0)}}
      <@form.Alert @icon="circle-info">
        {{i18n "category.localization.hint"}}
      </@form.Alert>
    {{/if}}

    <@form.Collection @name="localizations" as |collection index|>
      <collection.Field
        @name="category_id"
        @title="category_id"
        @showTitle={{false}}
        @disabled={{true}}
        as |field|
      >
        <field.Input @value={{this.category.id}} @type="hidden" />
      </collection.Field>

      <@form.Row as |row|>
        <row.Col @size={{2}}>
          <collection.Field
            @name="locale"
            @title={{i18n "category.localization.locale"}}
            @format="full"
            @validation="required"
            as |field|
          >
            <field.Select as |select|>
              {{#each this.availableLocales as |locale|}}
                <select.Option
                  @value={{locale.value}}
                >{{locale.name}}</select.Option>
              {{/each}}
            </field.Select>
          </collection.Field>
        </row.Col>

        <row.Col @size={{4}}>
          <collection.Field
            @name="name"
            @title={{i18n "category.localization.name"}}
            @validation="required|length:1,50"
            as |field|
          >
            <field.Input
              placeholder={{i18n "category.name_placeholder"}}
              @maxlength="50"
              class="category-name"
            />
          </collection.Field>
        </row.Col>

        <row.Col @size={{5}}>
          <collection.Field
            @name="description"
            @title={{i18n "category.localization.description"}}
            as |field|
          >
            <field.Textarea @height={{60}} />
          </collection.Field>
        </row.Col>

        <row.Col @size={{1}}>
          <@form.Button
            class="btn-danger remove-localization"
            @icon="trash-can"
            @title="category.localization.remove"
            @action={{fn collection.remove index}}
          />
        </row.Col>
      </@form.Row>
    </@form.Collection>

    <@form.Button
      class="add-localization"
      @icon="plus"
      @label="category.localization.add"
      @action={{fn
        @form.addItemToCollection
        "localizations"
        (hash category_id=this.category.id locale="" name="" description="")
      }}
    />
  </template>
}
