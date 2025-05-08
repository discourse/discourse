import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Composer from "discourse/models/composer";
import PostLocalization from "discourse/models/post-localization";
import TopicLocalization from "discourse/models/topic-localization";
import { i18n } from "discourse-i18n";
import DTooltip from "float-kit/components/d-tooltip";

export default class PostMetaDataTranslationIndicator extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;

  get postLocalizationsCount() {
    return this.args.post?.post_localizations.length;
  }

  get originalPostContent() {
    return `<div class='d-editor-translation-preview-wrapper'>
         <span class='d-editor-translation-preview-wrapper__header'>
          ${i18n("composer.translations.original_content")}
         </span>
          ${this.args.post.cooked}
      </div>`;
  }

  @action
  async editLocalization(locale) {
    if (
      !this.currentUser ||
      !this.siteSettings.experimental_content_localization ||
      !this.currentUser.can_localize_content
    ) {
      return;
    }

    await this.composer.open({
      action: Composer.ADD_TRANSLATION,
      draftKey: "translation",
      warningsDisabled: true,
      hijackPreview: this.originalPostContent,
      post: this.args.post,
      selectedTranslationLocale: locale.locale,
    });
    this.composer.model.set("reply", locale.raw);
  }

  @action
  async deleteLocalization(locale) {
    try {
      await PostLocalization.destroy(this.args.post.id, locale);

      if (this.args.post.firstPost) {
        await TopicLocalization.destroy(this.args.post.topic_id, locale);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      window.location.reload();
    }
  }

  <template>
    <div class="post-info translations">
      <DTooltip
        @triggerClass="btn-flat"
        @placement="bottom-start"
        @arrow={{true}}
        @identifier="post-meta-data-translation-indicator"
        @interactive={{true}}
      >
        <:trigger>
          <span class="translation-count">{{this.postLocalizationsCount}}</span>
          {{icon "globe"}}
        </:trigger>
        <:content>
          <table>
            <thead>
              <tr>
                <th>{{i18n "post.localizations.table.locale"}}</th>
                <th>{{i18n "post.localizations.table.actions"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each @post.post_localizations as |localization|}}
                <tr>
                  <td>{{localization.locale}}</td>
                  <td>
                    <DButton
                      class="btn-primary btn-transparent"
                      @label="post.localizations.table.edit"
                      @action={{fn this.editLocalization localization}}
                    />
                  </td>
                  <td>
                    <DButton
                      class="btn-danger btn-transparent"
                      @label="post.localizations.table.delete"
                      @action={{fn this.deleteLocalization localization.locale}}
                    />
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        </:content>
      </DTooltip>
    </div>
  </template>
}
