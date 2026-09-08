import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import PostLocalization from "discourse/models/post-localization";
import DEditor from "discourse/ui-kit/d-editor";
import DTextField from "discourse/ui-kit/d-text-field";
import { i18n } from "discourse-i18n";

export default class PostTranslationEditor extends Component {
  @service composer;
  @service siteSettings;

  constructor() {
    super(...arguments);
    this.initializeFromSelectedLocale();
  }

  async initializeFromSelectedLocale() {
    if (this.composer.selectedTranslationLocale && !this.composer.model.reply) {
      const localization = await this.findCurrentLocalization();
      if (localization) {
        this.composer.model.setProperties({
          reply: localization.raw,
          originalText: localization.raw,
        });

        if (localization?.topic_localization) {
          this.composer.model.setProperties({
            title: localization.topic_localization.title,
            originalTitle: localization.topic_localization.title,
          });
        }
      } else {
        this.composer.model.setProperties({
          originalText: "",
          originalTitle: "",
        });
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

  @action
  handleInput(event) {
    this.composer.model.set("reply", event.target.value);
  }

  @action
  setupUploads(element) {
    if (this.args.uppyComposerUpload && this.composer.allowUpload) {
      this.args.uppyComposerUpload.setup(element);
      this._uploadsSetup = true;
    }
  }

  @action
  teardownUploads(element) {
    if (this._uploadsSetup && this.args.uppyComposerUpload) {
      this.args.uppyComposerUpload.teardown(element);
      this._uploadsSetup = false;
    }
  }

  <template>
    {{#if this.composer.model.post.firstPost}}
      <div class="topic-title-translator title-and-category with-preview">
        <div class="title-input-column">
          <DTextField
            @autocomplete="off"
            @disabled={{this.composer.loading}}
            @id="translated-topic-title"
            @maxLength={{this.siteSettings.max_topic_title_length}}
            @placeholder={{this.composer.model.topic.title}}
            @value={{this.composer.model.title}}
          />
        </div>
        <div class="title-preview-spacer"></div>
      </div>
    {{/if}}

    <DEditor
      class="translation-editor"
      @categoryId={{this.composer.model.category.id}}
      @change={{this.handleInput}}
      @composerEvents={{true}}
      @disabled={{this.composer.disableTextarea}}
      @disableSubmit={{this.composer.disableSubmit}}
      @extraButtons={{@extraButtons}}
      @forcePreview={{true}}
      @hijackPreview={{this.composer.hijackPreview}}
      @loading={{this.composer.loading}}
      @onPopupMenuAction={{this.composer.onPopupMenuAction}}
      @onSetup={{@setupEditor}}
      @outletArgs={{lazyHash
        composer=this.composer.model
        editorType="composer"
      }}
      @placeholder={{i18n "composer.translations.placeholder"}}
      @popupMenuOptions={{this.composer.popupMenuOptions}}
      @processPreview={{false}}
      @showLink={{@showLink}}
      @topicId={{this.composer.model.topic.id}}
      @value={{readonly this.composer.model.reply}}
      {{didInsert this.setupUploads}}
      {{willDestroy this.teardownUploads}}
    />
  </template>
}
