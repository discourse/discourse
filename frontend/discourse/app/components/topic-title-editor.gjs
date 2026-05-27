import Component from "@glimmer/component";
import { service } from "@ember/service";
import lazyHash from "discourse/helpers/lazy-hash";
import DTextField from "discourse/ui-kit/d-text-field";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dAutoFocus from "discourse/ui-kit/modifiers/d-auto-focus";
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
          {{dIcon "language"}}
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
          <DTextField
            @id="edit-title"
            @value={{@translationTitle}}
            @maxlength={{this.siteSettings.max_topic_title_length}}
            @autofocus={{true}}
            {{dAutoFocus}}
          />
        {{else}}
          <DTextField
            @id="edit-title"
            @value={{@bufferedTitle}}
            @maxlength={{this.siteSettings.max_topic_title_length}}
            @autofocus={{true}}
            {{dAutoFocus}}
          />
        {{/if}}
      </PluginOutlet>
    </div>
  </template>
}
