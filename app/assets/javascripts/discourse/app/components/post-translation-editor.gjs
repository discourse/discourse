import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DEditor from "discourse/components/d-editor";
import TextField from "discourse/components/text-field";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import PostLocalization from "discourse/models/post-localization";
import { i18n } from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";

export default class PostTranslationEditor extends Component {
  @service composer;
  @service siteSettings;
  @service languageNameLookup;

  constructor() {
    super(...arguments);
    this.initializeFromSelectedLocale();
  }

  async initializeFromSelectedLocale() {
    if (this.composer.selectedTranslationLocale && !this.composer.model.reply) {
      const localization = await this.findCurrentLocalization();
      if (localization) {
        this.composer.model.set("reply", localization.raw);

        if (localization?.topic_localization) {
          this.composer.model.set(
            "title",
            localization.topic_localization.title
          );
        }
      }
    }
  }

  async findCurrentLocalization() {
    try {
      const { post_localizations } = await PostLocalization.find(
        this.composer.model.post.id
      );

      return post_localizations.find(
        (localization) =>
          localization.locale === this.composer.selectedTranslationLocale
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  get availableContentLocalizationLocales() {
    const originalPostLocale = this.composer.model?.post?.locale;

    return this.siteSettings.available_content_localization_locales
      .filter(({ value }) => value !== originalPostLocale)
      .map(({ value }) => ({
        name: this.languageNameLookup.getLanguageName(value),
        value,
      }));
  }

  @action
  handleInput(event) {
    this.composer.model.set("reply", event.target.value);
  }

  @action
  async updateSelectedLocale(locale) {
    this.composer.selectedTranslationLocale = locale;

    const currentLocalization = await this.findCurrentLocalization();

    if (currentLocalization) {
      this.composer.model.set("reply", currentLocalization.raw);

      if (currentLocalization?.topic_localization) {
        this.composer.model.set(
          "title",
          currentLocalization.topic_localization.title
        );
      }
    } else {
      this.composer.model.setProperties({
        reply: "",
        title: "",
      });
    }
  }

  <template>
    <div>
      <DropdownSelectBox
        @nameProperty="name"
        @valueProperty="value"
        @value={{this.composer.selectedTranslationLocale}}
        @content={{this.availableContentLocalizationLocales}}
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

    <DEditor
      class="translation-editor"
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
  </template>
}
