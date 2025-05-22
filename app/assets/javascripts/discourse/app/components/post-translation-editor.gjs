import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DEditor from "discourse/components/d-editor";
import TextField from "discourse/components/text-field";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

export default class PostTranslationEditor extends Component {
  @service composer;
  @service siteSettings;

  get availableLocales() {
    return JSON.parse(this.siteSettings.available_locales);
  }

  findCurrentLocalization() {
    return this.composer.model.post.post_localizations.find(
      (localization) =>
        localization.locale === this.composer.selectedTranslationLocale
    );
  }

  @action
  handleInput(event) {
    this.composer.model.set("reply", event.target.value);
  }

  @action
  updateSelectedLocale(locale) {
    this.composer.selectedTranslationLocale = locale;

    const currentLocalization = this.findCurrentLocalization();

    if (currentLocalization) {
      this.composer.model.set("reply", currentLocalization.raw);
    }
  }

  <template>
    <div>
      <DropdownSelectBox
        @nameProperty="name"
        @valueProperty="value"
        @value={{this.composer.selectedTranslationLocale}}
        @content={{this.availableLocales}}
        @onChange={{this.updateSelectedLocale}}
        @options={{hash
          icon="globe"
          showCaret=true
          filterable=true
          disabled=this.composer.loading
          placement="bottom-start"
          translatedNone=(i18n "composer.translations.select")
        }}
        class="translation-selector-dropdown btn-small"
      />
    </div>

    {{#if this.composer.model.post.firstPost}}
      <div class="topic-title-translator title-and-category with-preview">
        <TextField
          @value={{this.composer.model.title}}
          @id="translated-topic-title"
          @maxLength={{this.siteSettings.max_topic_title_length}}
          @placeholder={{this.composer.model.topic.title}}
          @disabled={{this.composer.loading}}
          @autocomplete="off"
        />
      </div>
    {{/if}}

    <div class="d-editor translation-editor">
      <DEditor
        @value={{readonly this.composer.model.reply}}
        @change={{this.handleInput}}
        @placeholder="composer.translations.placeholder"
        @forcePreview={{true}}
        @processPreview={{false}}
        @loading={{this.composer.loading}}
        @hijackPreview={{this.composer.hijackPreview}}
        @disabled={{this.composer.disableTextarea}}
        @onSetup={{@setupEditor}}
        @disableSubmit={{this.composer.disableSubmit}}
        @topicId={{this.composer.model.topic.id}}
        @categoryId={{this.composer.model.category.id}}
        @outletArgs={{lazyHash
          composer=this.composer.model
          editorType="composer"
        }}
      />
    </div>
  </template>
}
