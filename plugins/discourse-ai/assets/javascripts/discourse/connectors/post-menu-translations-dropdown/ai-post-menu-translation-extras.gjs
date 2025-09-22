import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
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

  async #refresh() {
    // TODO(@nat): handle request to refresh translations for post
    // we need a route to call and handle the refresh on the backend
  }

  @action
  refreshTranslations() {
    const confirmMessage = i18n(
      "discourse_ai.translations.translations_menu.refresh.confirm"
    );

    return this.dialog.yesNoConfirm({
      message: confirmMessage,
      didConfirm: async () => {
        try {
          await this.#refresh();

          this.toasts.success({
            duration: "short",
            data: {
              message: i18n(
                "discourse_ai.translations.translations_menu.refresh.success"
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
    <@dropdown.item class="update-translations-menu__refresh">
      <DButton
        class="post-action-menu__refresh-translation"
        @label="discourse_ai.translations.translations_menu.refresh.label"
        @icon="arrows-rotate"
        @action={{this.refreshTranslations}}
      />
    </@dropdown.item>

    {{yield}}
  </template>
}
