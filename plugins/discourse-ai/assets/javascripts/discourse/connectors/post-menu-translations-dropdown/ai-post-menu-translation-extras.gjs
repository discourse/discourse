import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AiPostMenuTranslationExtras extends Component {
  static shouldRender(args, { siteSettings, currentUser }) {
    return (
      siteSettings.discourse_ai_enabled &&
      siteSettings.ai_translation_enabled &&
      currentUser.can_localize_content
    );
  }

  @service dialog;
  @service toasts;

  async #translate() {
    try {
      await ajax(`/discourse-ai/translate/posts/${this.args.post.id}`, {
        type: "POST",
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  translate() {
    const confirmMessage = i18n(
      "discourse_ai.translations.translations_menu.translate.confirm"
    );

    return this.dialog.yesNoConfirm({
      message: confirmMessage,
      didConfirm: async () => {
        try {
          await this.#translate();

          this.toasts.success({
            duration: "short",
            data: {
              message: i18n(
                "discourse_ai.translations.translations_menu.translate.success"
              ),
            },
          });
        } catch (e) {
          popupAjaxError(e);
        }
      },
    });
  }

  <template>
    <@dropdown.item class="update-translations-menu__translate">
      <DButton
        class="post-action-menu__translate-translation"
        @label="discourse_ai.translations.translations_menu.translate.label"
        @icon="arrows-rotate"
        @action={{this.translate}}
        @title="discourse_ai.translations.translations_menu.translate.title"
      />
    </@dropdown.item>
    {{yield}}
  </template>
}
