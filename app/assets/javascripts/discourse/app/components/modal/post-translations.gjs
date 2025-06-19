import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Composer from "discourse/models/composer";
import PostLocalization from "discourse/models/post-localization";
import TopicLocalization from "discourse/models/topic-localization";
import { i18n } from "discourse-i18n";

export default class PostTranslationsModal extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;
  @service dialog;

  @tracked postLocalizations = null;
  @tracked loading = false;

  constructor() {
    super(...arguments);
    this.loadPostLocalizations();
  }

  get originalPostContent() {
    const originalLocale =
      this.args.model.post?.locale || this.siteSettings.default_locale;

    return `<div class='d-editor-translation-preview-wrapper'>
         <span class='d-editor-translation-preview-wrapper__header'>
          ${i18n("composer.translations.original_content")}
            <span class='d-editor-translation-preview-wrapper__original-locale'>
               ${originalLocale}
            </span>
         </span>
          ${this.args.model.post.cooked}
      </div>`;
  }

  async loadPostLocalizations() {
    this.loading = true;

    try {
      const { post_localizations } = await PostLocalization.find(
        this.args.model.post.id
      );

      this.postLocalizations = post_localizations;
      this.loading = false;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async editLocalization(locale) {
    if (
      !this.currentUser ||
      !this.siteSettings.content_localization_enabled ||
      !this.currentUser.can_localize_content
    ) {
      return;
    }

    this.args.closeModal();

    const composerOpts = {
      action: Composer.ADD_TRANSLATION,
      draftKey: "translation",
      warningsDisabled: true,
      hijackPreview: this.originalPostContent,
      post: this.args.model.post,
      selectedTranslationLocale: locale.locale,
    };

    if (locale?.topic_localization) {
      composerOpts.topicTitle = locale.topic_localization?.title;
    }

    await this.composer.open(composerOpts);
    this.composer.model.set("reply", locale.raw);
  }

  @action
  async deleteLocalization(locale) {
    try {
      await PostLocalization.destroy(this.args.model.post.id, locale);

      if (this.args.model.post.firstPost) {
        await TopicLocalization.destroy(this.args.model.post.topic_id, locale);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      window.location.reload();
    }
  }

  @action
  delete(locale) {
    return this.dialog.yesNoConfirm({
      message: i18n("post.localizations.modal.confirm_delete", {
        languageCode: locale,
      }),
      didConfirm: () => {
        return this.deleteLocalization(locale);
      },
    });
  }

  <template>
    <DModal
      @title={{i18n "post.localizations.modal.title"}}
      @closeModal={{@closeModal}}
      class="post-translations-modal"
    >
      <:body>
        <ConditionalLoadingSpinner @size="large" @condition={{this.loading}} />

        {{#if this.postLocalizations}}
          <table>
            <thead>
              <tr>
                <th>{{i18n "post.localizations.table.locale"}}</th>
                <th>{{i18n "post.localizations.table.actions"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.postLocalizations as |localization|}}
                <tr>
                  <td
                    class="post-translations-modal__locale"
                  >{{localization.locale}}</td>
                  <td class="post-translations-modal__edit-action">
                    <DButton
                      class="btn-primary btn-transparent"
                      @icon="pencil"
                      @label="post.localizations.table.edit"
                      @action={{fn this.editLocalization localization}}
                    />
                  </td>
                  <td class="post-translations-modal__delete-action">
                    <DButton
                      class="btn-danger btn-transparent"
                      @icon="trash-can"
                      @label="post.localizations.table.delete"
                      @action={{fn this.delete localization.locale}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
