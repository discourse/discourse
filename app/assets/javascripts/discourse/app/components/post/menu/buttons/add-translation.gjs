import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";

export default class PostMenuAddTranslationButton extends Component {
  @service composer;
  @service currentUser;
  @service siteSettings;

  @tracked showComposer = false;

  get originalPostContent() {
    return `<div class='d-editor-translation-preview-wrapper'>
         <span class='d-editor-translation-preview-wrapper__header'>
          ${i18n("composer.translations.original_content")}
         </span>
          ${this.args.post.cooked}
      </div>`;
  }

  @action
  async addTranslation() {
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
    });
  }

  <template>
    <DButton
      class="post-action-menu__add-translation"
      @icon="discourse-add-translation"
      @action={{this.addTranslation}}
      ...attributes
    />
  </template>
}
