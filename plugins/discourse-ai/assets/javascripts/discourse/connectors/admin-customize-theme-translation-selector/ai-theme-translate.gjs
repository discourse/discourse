import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AiThemeTranslate extends Component {
  static shouldRender(args, { siteSettings }) {
    return (
      siteSettings.discourse_ai_enabled && siteSettings.ai_translation_enabled
    );
  }

  @service toasts;

  @action
  async translate() {
    const { theme } = this.args.outletArgs;
    try {
      await ajax("/admin/plugins/discourse-ai/ai-theme-translations", {
        type: "POST",
        data: { theme_id: theme.id },
      });
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "discourse_ai.translations.theme_translations.translate.queued"
          ),
        },
      });
    } catch (e) {
      this.toasts.error({
        duration: "short",
        data: {
          message: extractError(
            e,
            i18n(
              "discourse_ai.translations.theme_translations.translate.failed"
            )
          ),
        },
      });
    }
  }

  <template>
    <DButton
      class="btn-default ai-theme-translate"
      @icon="discourse-sparkles"
      @label="discourse_ai.translations.theme_translations.translate.label"
      @title="discourse_ai.translations.theme_translations.translate.title"
      @action={{this.translate}}
    />
  </template>
}
