import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import AiThemeTranslationModal from "discourse/plugins/discourse-ai/discourse/components/modal/ai-theme-translation-modal";

export default class AiThemeTranslate extends Component {
  static shouldRender(args, { siteSettings }) {
    return (
      siteSettings.discourse_ai_enabled && siteSettings.ai_translation_enabled
    );
  }

  @service modal;

  @action
  translate() {
    const { theme, locale } = this.args.outletArgs;
    this.modal.show(AiThemeTranslationModal, { model: { theme, locale } });
  }

  <template>
    <DButton
      class="btn-default ai-theme-translate"
      @action={{this.translate}}
      @icon="discourse-sparkles"
      @label="discourse_ai.translations.theme_translations.translate.label"
      @title="discourse_ai.translations.theme_translations.translate.title"
    />
  </template>
}
