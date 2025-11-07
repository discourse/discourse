import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import CookText from "discourse/components/cook-text";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { i18n } from "discourse-i18n";

export default class DEditorOriginalTranslationPreview extends Component {
  @tracked showOriginal = true;
  @tracked showRawMarkdown = false;

  get originalLocale() {
    return this.args.model.postLocale;
  }

  get translationText() {
    return typeof this.args.model.translationText === "function"
      ? this.args.model.translationText()
      : this.args.model.translationText;
  }

  @action
  setView(view) {
    this.showOriginal = view === "original";
    this.showRawMarkdown = false;
  }

  @action
  toggleRawMarkdown() {
    this.showRawMarkdown = !this.showRawMarkdown;
  }

  <template>
    <div class="d-editor-translation-preview-wrapper">
      <div class="d-editor-translation-preview-header">
        <span class="d-editor-translation-preview-header__title">
          {{#if this.showOriginal}}
            {{i18n "composer.translations.original_content"}}
            <span class="d-editor-translation-preview-wrapper__original-locale">
              {{this.originalLocale}}
            </span>
            <div class="d-editor-translation-preview-header__raw-toggle">
              <DToggleSwitch
                @state={{this.showRawMarkdown}}
                @label="composer.translations.show_raw_markdown"
                {{on "click" this.toggleRawMarkdown}}
              />
            </div>
          {{else}}
            {{i18n "composer.translations.translation_preview"}}
          {{/if}}
        </span>

        <div class="d-editor-translation-preview-header__controls">
          <button
            type="button"
            class="btn btn-flat btn-small {{if this.showOriginal 'active'}}"
            {{on "click" (fn this.setView "original")}}
          >
            {{i18n "composer.translations.original"}}
          </button>
          <button
            type="button"
            class="btn btn-flat btn-small {{unless this.showOriginal 'active'}}"
            {{on "click" (fn this.setView "translation")}}
          >
            {{i18n "composer.translations.translation"}}
          </button>
        </div>
      </div>

      <div class="d-editor-translation-preview-content">
        {{#if this.showOriginal}}
          {{#if this.showRawMarkdown}}
            {{#if @model.rawPost}}
              <pre
                class="d-editor-translation-preview-raw"
              >{{@model.rawPost}}</pre>
            {{/if}}
          {{else}}
            {{#if @model.cookedPost}}
              {{htmlSafe @model.cookedPost}}
            {{else if @model.rawPost}}
              <CookText @rawText={{@model.rawPost}} />
            {{/if}}
          {{/if}}
        {{else}}
          {{#if this.translationText}}
            <CookText @rawText={{this.translationText}} />
          {{else}}
            <div class="d-editor-translation-preview-empty">
              {{i18n "composer.translations.no_translation_yet"}}
            </div>
          {{/if}}
        {{/if}}
      </div>
    </div>
  </template>
}
