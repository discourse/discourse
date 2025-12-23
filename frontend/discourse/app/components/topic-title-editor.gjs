import Component from "@glimmer/component";
import { service } from "@ember/service";
import TextField from "discourse/components/text-field";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import autoFocus from "discourse/modifiers/auto-focus";
import { i18n } from "discourse-i18n";
import PluginOutlet from "./plugin-outlet";

export default class TopicTitleEditor extends Component {
  @service languageNameLookup;
  @service siteSettings;

  get translationLocaleName() {
    return this.languageNameLookup.getLanguageName(this.args.translationLocale);
  }

  <template>
    <div class="edit-title__wrapper">
      {{#if @isEditingLocalization}}
        <span class="editing-localization-indicator">
          {{icon "language"}}
          {{i18n
            "topic.localizations.editing_translation"
            language=this.translationLocaleName
          }}
        </span>
      {{/if}}
      <PluginOutlet
        @name="edit-topic-title"
        @outletArgs={{lazyHash model=@model buffered=@buffered}}
      >
        {{#if @isEditingLocalization}}
          <TextField
            @id="edit-title"
            @value={{@translationTitle}}
            @maxlength={{this.siteSettings.max_topic_title_length}}
            @autofocus={{true}}
            {{autoFocus}}
          />
        {{else}}
          <TextField
            @id="edit-title"
            @value={{@bufferedTitle}}
            @maxlength={{this.siteSettings.max_topic_title_length}}
            @autofocus={{true}}
            {{autoFocus}}
          />
        {{/if}}
      </PluginOutlet>
    </div>
  </template>
}
