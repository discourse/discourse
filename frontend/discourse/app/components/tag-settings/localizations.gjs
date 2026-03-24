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

    {{#if @localizations.length}}
      <@form.Collection @name="localizations" as |collection index|>
        <collection.Field
          @name="tag_id"
          @type="input-hidden"
          @title="tag_id"
          @showTitle={{false}}
          @disabled={{true}}
          as |field|
        >
          <field.Control @value={{@tagId}} />
        </collection.Field>

        <@form.Row as |row|>
          <row.Col @size={{2}}>
            <collection.Field
              @name="locale"
              @type="select"
              @title={{i18n "tagging.localization.locale"}}
              @validation="required"
              as |field|
            >
              <field.Control as |select|>
                {{#each this.selectableLocales as |locale|}}
                  <select.Option
                    @value={{locale.value}}
                  >{{locale.name}}</select.Option>
                {{/each}}
              </field.Control>
            </collection.Field>
          </row.Col>

          <row.Col @size={{3}}>
            <collection.Field
              @name="name"
              @type="input"
              @title={{i18n "tagging.localization.name"}}
              @validation="required|length:1,50"
              as |field|
            >
              <field.Control
                placeholder={{i18n "tagging.settings.name_placeholder"}}
                @maxlength="50"
              />
            </collection.Field>
          </row.Col>

          <row.Col @size={{6}}>
            <collection.Field
              @name="description"
              @type="textarea"
              @title={{i18n "tagging.localization.description"}}
              @validation="length:0,1000"
              as |field|
            >
              <field.Control @height={{80}} />
            </collection.Field>
          </row.Col>

          <row.Col @size={{1}}>
            <@form.Button
              class="btn-danger"
              @icon="trash-can"
              @title="tagging.localization.remove"
              @action={{fn collection.remove index}}
            />
          </row.Col>
        </@form.Row>
      </@form.Collection>
    {{/if}}
    <@form.Button
      class="btn-default"
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
