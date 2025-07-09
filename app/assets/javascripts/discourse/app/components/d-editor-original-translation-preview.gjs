import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import CookText from "discourse/components/cook-text";
import { i18n } from "discourse-i18n";

export default class DEditorOriginalTranslationPreview extends Component {
  @service siteSettings;

  get originalLocale() {
    return this.args.model.postLocale;
  }

  <template>
    <div class="d-editor-translation-preview-wrapper">
      <span class="d-editor-translation-preview-wrapper__header">
        {{i18n "composer.translations.original_content"}}
        <span class="d-editor-translation-preview-wrapper__original-locale">
          {{this.originalLocale}}
        </span>
      </span>

      {{#if @model.cookedPost}}
        {{htmlSafe @model.cookedPost}}
      {{else if @model.rawPost}}
        <CookText @rawText={{@model.rawPost}} />
      {{/if}}
    </div>
  </template>
}
