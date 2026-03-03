import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DEditor from "discourse/components/d-editor";
import TextField from "discourse/components/text-field";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import PostLocalization from "discourse/models/post-localization";
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
          <TextField
            @value={{this.composer.model.title}}
            @id="translated-topic-title"
            @maxLength={{this.siteSettings.max_topic_title_length}}
            @placeholder={{this.composer.model.topic.title}}
            @disabled={{this.composer.loading}}
            @autocomplete="off"
          />
        </div>
        <div class="title-preview-spacer"></div>
      </div>
    {{/if}}

    <DEditor
      class="translation-editor"
      @value={{readonly this.composer.model.reply}}
      @change={{this.handleInput}}
      @placeholder={{i18n "composer.translations.placeholder"}}
      @extraButtons={{@extraButtons}}
      @forcePreview={{true}}
      @processPreview={{false}}
      @composerEvents={{true}}
      @onPopupMenuAction={{this.composer.onPopupMenuAction}}
      @popupMenuOptions={{this.composer.popupMenuOptions}}
      @showLink={{@showLink}}
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
      {{didInsert this.setupUploads}}
      {{willDestroy this.teardownUploads}}
    />
  </template>
}
