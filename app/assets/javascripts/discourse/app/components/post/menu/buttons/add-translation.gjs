import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import PostTranslationsModal from "discourse/components/modal/post-translations";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class PostMenuAddTranslationButton extends Component {
  @service composer;
  @service modal;
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

  get showTranslationButton() {
    return (
      this.currentUser &&
      this.siteSettings.experimental_content_localization &&
      this.currentUser.can_localize_content
    );
  }

  get viewTranslationLabel() {
    return i18n("post.localizations.view", {
      count: this.args.post.post_localizations_count,
    });
  }

  get showAsMenu() {
    return this.args.post.post_localizations_count > 0;
  }

  @action
  viewTranslations() {
    // TODO: trigger a modal to view/edit translations
    this.modal.show(PostTranslationsModal, { model: { post: this.args.post } });
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

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  <template>
    {{#if this.showTranslationButton}}
      {{#if this.showAsMenu}}
        <DMenu
          ...attributes
          @identifier="post-action-menu-edit-translations"
          @triggers={{array "click"}}
          class="update-translations-menu"
          @title="post.localizations.add"
          @icon="discourse-add-translation"
          @onRegisterApi={{this.onRegisterApi}}
          @arrow={{false}}
        >
          <:content>
            <DropdownMenu as |dropdown|>
              <dropdown.item class="update-translations-menu__view">
                <DButton
                  class="post-action-menu__view-translation"
                  @translatedLabel={{this.viewTranslationLabel}}
                  @icon="eye"
                  @action={{this.viewTranslations}}
                  ...attributes
                />
              </dropdown.item>
              <dropdown.item class="update-translations-menu__add">
                <DButton
                  class="post-action-menu__add-translation"
                  @label="post.localizations.add"
                  @icon="plus"
                  @action={{this.addTranslation}}
                  ...attributes
                />
              </dropdown.item>
            </DropdownMenu>
          </:content>
        </DMenu>
      {{else}}
        <DButton
          class="post-action-menu__add-translation"
          @title="post.localizations.add"
          @icon="discourse-add-translation"
          @action={{this.addTranslation}}
          ...attributes
        />
      {{/if}}
    {{/if}}
  </template>
}
