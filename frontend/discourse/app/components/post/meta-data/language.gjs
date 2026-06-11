import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class PostMetaDataLanguage extends Component {
  @service languageNameLookup;

  @tracked toggling = false;

  get language() {
    const lang = this.args.post?.language;
    return this.languageNameLookup.getLanguageName(lang);
  }

  get outdated() {
    return this.args.post?.localization_outdated;
  }

  get viewingOriginal() {
    return this.args.post?.viewingOriginalContent;
  }

  get label() {
    if (this.viewingOriginal) {
      return i18n("post.localized_content_toggle.viewing_original");
    }

    return i18n("post.localized_content_toggle.original_language", {
      language: this.language,
    });
  }

  get title() {
    if (this.viewingOriginal) {
      return i18n("post.localized_content_toggle.view_translation");
    }

    const i18nKey = this.outdated
      ? "post.original_language_and_outdated"
      : "post.original_language";

    return `${i18n(i18nKey, { language: this.language })} ${i18n(
      "post.ai_translation_disclaimer"
    )} ${i18n("post.localized_content_toggle.view_original")}`;
  }

  @action
  async toggle() {
    this.toggling = true;

    try {
      await this.args.post.toggleOriginalContent();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.toggling = false;
    }
  }

  <template>
    <div class="post-info post-language">
      <DButton
        class={{dConcatClass
          "btn-flat"
          "post-language__toggle"
          (if this.outdated "heatmap-low")
        }}
        @action={{this.toggle}}
        @translatedLabel={{this.label}}
        @translatedTitle={{this.title}}
        @suffixIcon="language"
        @disabled={{this.toggling}}
      />
    </div>
  </template>
}
