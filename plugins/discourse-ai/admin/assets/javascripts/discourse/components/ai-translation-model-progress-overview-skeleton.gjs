import { i18n } from "discourse-i18n";

const PLACEHOLDERS = [0, 1, 2, 3];

export default <template>
  <div
    class="ai-translation-model-progress-overview-skeleton --animation"
    role="status"
    aria-label={{i18n "discourse_ai.translations.model_progress.loading"}}
  >
    {{#each PLACEHOLDERS}}
      <div class="ai-translation-model-progress-overview-skeleton__card">
        <div class="ai-translation-model-progress-overview-skeleton__header">
          <span
            class="ai-translation-model-progress-overview-skeleton__title"
          ></span>
          <span
            class="ai-translation-model-progress-overview-skeleton__percentage"
          ></span>
        </div>
        <span
          class="ai-translation-model-progress-overview-skeleton__headline"
        ></span>
        <span
          class="ai-translation-model-progress-overview-skeleton__subheader"
        ></span>
        <span
          class="ai-translation-model-progress-overview-skeleton__subheader"
        ></span>
        <span
          class="ai-translation-model-progress-overview-skeleton__meter"
        ></span>
      </div>
    {{/each}}
  </div>
</template>
