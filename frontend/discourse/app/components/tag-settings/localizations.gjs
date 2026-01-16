import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { service } from "@ember/service";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class TagSettingsLocalizations extends Component {
  @service siteSettings;
  @service languageNameLookup;

  get selectableLocales() {
    const supported =
      this.siteSettings.available_content_localization_locales.map(
        (obj) => obj.value
      );
    const committed = (this.args.localizations || []).map((obj) => obj.locale);
    const allLocales = uniqueItemsFromArray([...supported, ...committed]);

    return allLocales.map((value) => ({
      name: this.languageNameLookup.getLanguageName(value),
      value,
    }));
  }

  <template>
    {{#if (eq @localizations.length 0)}}
      <@form.Alert @icon="circle-info">
        {{i18n "tagging.localization.hint"}}
      </@form.Alert>
    {{/if}}

    <@form.Collection @name="localizations" as |collection index|>
      <div class="tag-settings-localization">
        <collection.Field
          @name="tag_id"
          @title="tag_id"
          @showTitle={{false}}
          @disabled={{true}}
          as |field|
        >
          <field.Input @value={{@tagId}} @type="hidden" />
        </collection.Field>

        <div class="tag-settings-localization__row">
          <collection.Field
            @name="locale"
            @title={{i18n "tagging.localization.locale"}}
            @validation="required"
            as |field|
          >
            <field.Select as |select|>
              {{#each this.selectableLocales as |locale|}}
                <select.Option
                  @value={{locale.value}}
                >{{locale.name}}</select.Option>
              {{/each}}
            </field.Select>
          </collection.Field>

          <collection.Field
            @name="name"
            @title={{i18n "tagging.localization.name"}}
            @validation="required|length:1,50"
            as |field|
          >
            <field.Input
              placeholder={{i18n "tagging.settings.name_placeholder"}}
              @maxlength="50"
              class="tag-name"
            />
          </collection.Field>

          <@form.Button
            class="btn-danger tag-settings-localization__remove"
            @icon="trash-can"
            @title="tagging.localization.remove"
            @action={{fn collection.remove index}}
          />
        </div>

        <collection.Field
          @name="description"
          @title={{i18n "tagging.localization.description"}}
          as |field|
        >
          <field.Textarea @height={{80}} />
        </collection.Field>
      </div>
    </@form.Collection>

    <@form.Button
      class="add-localization"
      @icon="plus"
      @label="tagging.localization.add"
      @action={{fn
        @form.addItemToCollection
        "localizations"
        (hash tag_id=@tagId locale="" name="" description="")
      }}
    />
  </template>
}
