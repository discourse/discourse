import { on } from "@ember/modifier";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DTextarea from "discourse/ui-kit/d-textarea";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

const QueryAiPrompt = <template>
  <div class="query-ai-prompt" ...attributes>
    <label class="query-ai-prompt__label" for="query-ai-prompt-input">
      {{i18n "explorer.ai.prompt_label"}}
    </label>
    <DTextarea
      class="query-ai-prompt__input"
      disabled={{@disabled}}
      id="query-ai-prompt-input"
      placeholder={{or
        @placeholder
        (i18n "explorer.ai.regenerate_placeholder")
      }}
      @value={{@value}}
      {{on "input" @onChange}}
    />
    <div class="query-ai-prompt__actions">
      <DButton
        aria-busy={{@generating}}
        class={{dConcatClass
          (or @actionClass "btn-default")
          "query-ai-prompt__regenerate"
        }}
        @action={{@onRegenerate}}
        @disabled={{@regenerateDisabled}}
        @icon="arrows-rotate"
        @isLoading={{@generating}}
        @label={{or @actionLabel "explorer.ai.regenerate"}}
      />
    </div>
  </div>
</template>;

export default QueryAiPrompt;
