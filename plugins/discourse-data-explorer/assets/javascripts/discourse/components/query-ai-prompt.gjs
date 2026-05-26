import { on } from "@ember/modifier";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DTextarea from "discourse/ui-kit/d-textarea";
import { i18n } from "discourse-i18n";

const QueryAiPrompt = <template>
  <div class="query-ai-prompt">
    <label class="query-ai-prompt__label" for="query-ai-prompt-input">
      {{i18n "explorer.ai.prompt_label"}}
    </label>
    <DTextarea
      @value={{@value}}
      {{on "input" @onChange}}
      placeholder={{i18n "explorer.ai.regenerate_placeholder"}}
      id="query-ai-prompt-input"
      class="query-ai-prompt__input"
      disabled={{@disabled}}
    />
    <div class="query-ai-prompt__actions">
      <DButton
        @action={{@onRegenerate}}
        @icon="arrows-rotate"
        @label="explorer.ai.regenerate"
        @disabled={{@regenerateDisabled}}
        class="btn-default query-ai-prompt__regenerate"
      />
      {{#if @generating}}
        <span
          class="query-ai-prompt__generating"
          role="status"
          aria-live="polite"
        >
          <DConditionalLoadingSpinner @condition={{true}} @size="small" />
          <span>{{i18n "explorer.ai.generating"}}</span>
        </span>
      {{/if}}
    </div>
  </div>
</template>;

export default QueryAiPrompt;
