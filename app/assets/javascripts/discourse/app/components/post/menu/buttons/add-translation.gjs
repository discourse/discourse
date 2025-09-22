import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DEditorOriginalTranslationPreview from "discourse/components/d-editor-original-translation-preview";
import DropdownMenu from "discourse/components/dropdown-menu";
import PostTranslationsModal from "discourse/components/modal/post-translations";
import { ajax } from "discourse/lib/ajax";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class PostMenuAddTranslationButton extends Component {
  @service composer;
  @service modal;
  @service currentUser;
  @service siteSettings;

  @tracked showComposer = false;

  get showTranslationButton() {
    return (
      this.currentUser &&
      this.siteSettings.content_localization_enabled &&
      this.currentUser.can_localize_content
    );
  }

  get addTranslationsLabel() {
    if (this.showAsMenu) {
      return i18n("post.localizations.manage", {
        count: this.args.post.post_localizations_count,
      });
    }

    return i18n("post.localizations.add");
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
    this.modal.show(PostTranslationsModal, { model: { post: this.args.post } });
  }

  @action
  async addTranslation() {
    if (
      !this.currentUser ||
      !this.siteSettings.content_localization_enabled ||
      !this.currentUser.can_localize_content
    ) {
      return;
    }

    const { raw } = await ajax(`/posts/${this.args.post.id}.json`);

    await this.composer.open({
      action: Composer.ADD_TRANSLATION,
      draftKey: "translation",
      warningsDisabled: true,
      hijackPreview: {
        component: DEditorOriginalTranslationPreview,
        model: {
          postLocale: this.args.post.locale,
          rawPost: raw,
        },
      },
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
          class="update-translations-menu"
          @title={{this.addTranslationsLabel}}
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
                />
              </dropdown.item>
              <dropdown.item class="update-translations-menu__add">
                <DButton
                  class="post-action-menu__add-translation"
                  @label="post.localizations.add"
                  @icon="plus"
                  @action={{this.addTranslation}}
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
