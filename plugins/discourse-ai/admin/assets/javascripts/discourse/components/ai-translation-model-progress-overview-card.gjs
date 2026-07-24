import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import { i18n } from "discourse-i18n";

export default class AiTranslationModelProgressOverviewCard extends Component {
  get totalCount() {
    return Math.max(Number(this.args.target.total_count) || 0, 0);
  }

  get translatedCount() {
    return Math.min(
      Math.max(Number(this.args.target.translated_count) || 0, 0),
      this.totalCount
    );
  }

  get needsLanguageDetectionCount() {
    return Math.min(
      Math.max(Number(this.args.target.needs_language_detection_count) || 0, 0),
      this.totalCount - this.translatedCount
    );
  }

  get percentage() {
    if (this.totalCount === 0) {
      return 0;
    }

    return Math.round((this.translatedCount / this.totalCount) * 100);
  }

  get translatedSegmentStyle() {
    return trustHTML(
      `width: ${(this.translatedCount / Math.max(this.totalCount, 1)) * 100}%`
    );
  }

  get needsLanguageDetectionSegmentStyle() {
    return trustHTML(
      `width: ${
        (this.needsLanguageDetectionCount / Math.max(this.totalCount, 1)) * 100
      }%`
    );
  }

  get title() {
    return i18n(
      `discourse_ai.translations.model_progress.targets.${this.args.target.target_type}.title`
    );
  }

  get isFullyTranslated() {
    return this.totalCount > 0 && this.translatedCount === this.totalCount;
  }

  get headline() {
    const key = this.isFullyTranslated
      ? "all_translated"
      : this.args.target.target_type === "tag"
        ? "total"
        : "eligible_total";

    return i18n(
      `discourse_ai.translations.model_progress.targets.${this.args.target.target_type}.${key}`,
      { count: this.totalCount }
    );
  }

  get translatedText() {
    return i18n(
      `discourse_ai.translations.model_progress.targets.${this.args.target.target_type}.translated`,
      { count: this.translatedCount }
    );
  }

  get needsLanguageDetectionText() {
    return i18n(
      `discourse_ai.translations.model_progress.targets.${this.args.target.target_type}.needs_language_detection`,
      { count: this.needsLanguageDetectionCount }
    );
  }

  @action
  toggle() {
    this.args.onToggle?.(this.args.target.target_type);
  }

  <template>
    <button
      type="button"
      class="ai-translation-model-progress-overview-card"
      data-target-type={{@target.target_type}}
      aria-expanded={{if @expanded "true" "false"}}
      {{on "click" this.toggle}}
    >
      <span class="ai-translation-model-progress-overview-card__header">
        <span class="ai-translation-model-progress-overview-card__title">
          {{this.title}}
        </span>
        <span class="ai-translation-model-progress-overview-card__percentage">
          {{this.percentage}}%
        </span>
      </span>

      <span class="ai-translation-model-progress-overview-card__headline">
        {{this.headline}}
      </span>

      {{#if this.isFullyTranslated}}
        <span
          class="ai-translation-model-progress-overview-card__subheader"
          aria-hidden="true"
        ></span>
        <span
          class="ai-translation-model-progress-overview-card__subheader"
          aria-hidden="true"
        ></span>
      {{else}}
        <span
          class="ai-translation-model-progress-overview-card__subheader ai-translation-model-progress-overview-card__translated"
        >
          {{this.translatedText}}
        </span>
        <span
          class="ai-translation-model-progress-overview-card__subheader ai-translation-model-progress-overview-card__needs-detection"
        >
          {{this.needsLanguageDetectionText}}
        </span>
      {{/if}}

      <span
        class="ai-translation-model-progress-overview-card__meter"
        aria-hidden="true"
      >
        <span
          class="ai-translation-model-progress-overview-card__meter-translated"
          style={{this.translatedSegmentStyle}}
        ></span>
        <span
          class="ai-translation-model-progress-overview-card__meter-needs-detection"
          style={{this.needsLanguageDetectionSegmentStyle}}
        ></span>
      </span>
    </button>
  </template>
}
