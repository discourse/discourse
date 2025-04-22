import { service } from "@ember/service";
import { buildCategoryPanel } from "discourse/components/edit-category-panel";
import { concat, fn, hash } from "@ember/helper";
import { i18n } from "discourse-i18n";

export default class EditCategoryLocalizations extends buildCategoryPanel(
  "localizations"
) {
  @service siteSettings;

  get availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  }

  <template>
    <@form.Collection @name="localizations" as |collection index|>
      <@form.Row as |row|>
        <row.Col @size={{2}}>
          <collection.Field
            @name="locale"
            @title={{i18n "category.localization.locale"}}
            @format="full"
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
            class="btn-danger"
            @icon="trash-can"
            @title="category.localization.remove"
            @action={{fn collection.remove index}}
          />
        </row.Col>
      </@form.Row>
    </@form.Collection>

    <@form.Button
      @icon="plus"
      @label="category.localization.add"
      @action={{fn
        @form.addItemToCollection
        "localizations"
        (hash locale="" name="" description="")
      }}
    />
  </template>
}
