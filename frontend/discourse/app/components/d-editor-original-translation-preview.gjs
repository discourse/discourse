import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { waitForPromise } from "@ember/test-waiters";
import { ajax } from "discourse/lib/ajax";
import { cook } from "discourse/lib/text";
import { resolveAllShortUrls } from "discourse/lib/upload-short-url";
import DCookText from "discourse/ui-kit/d-cook-text";
import DDecoratedHtml, {
  applyHtmlDecorators,
} from "discourse/ui-kit/d-decorated-html";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

class DecoratedPreviewCookText extends Component {
  @service siteSettings;

  @tracked cooked = null;

  constructor(owner, args) {
    super(owner, args);
    this.loadCookedText();
  }

  @action
  async loadCookedText() {
    const rawText = this.args.rawText;
    const cooked = await waitForPromise(cook(rawText, { previewing: true }));

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    if (this.args.rawText !== rawText) {
      return;
    }

    this.cooked = trustHTML(cooked);
  }

  @action
  decoratePreview(preview, helper) {
    applyHtmlDecorators(preview, helper);
    resolveAllShortUrls(ajax, this.siteSettings, preview);
  }

  <template>
    <div {{didUpdate this.loadCookedText @rawText}}>
      <DDecoratedHtml
        @className="d-editor-preview"
        @decorate={{this.decoratePreview}}
        @html={{this.cooked}}
      />
    </div>
  </template>
}

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
            {{#if this.originalLocale}}
              <span
                class="d-editor-translation-preview-wrapper__original-locale"
              >
                {{this.originalLocale}}
              </span>
            {{/if}}
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
              {{trustHTML @model.cookedPost}}
            {{else if @model.rawPost}}
              <DCookText @rawText={{@model.rawPost}} />
            {{/if}}
          {{/if}}
        {{else}}
          {{#if this.translationText}}
            <DecoratedPreviewCookText @rawText={{this.translationText}} />
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
