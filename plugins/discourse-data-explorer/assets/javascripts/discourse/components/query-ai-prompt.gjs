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
      @value={{@value}}
      {{on "input" @onChange}}
      placeholder={{or
        @placeholder
        (i18n "explorer.ai.regenerate_placeholder")
      }}
      id="query-ai-prompt-input"
      class="query-ai-prompt__input"
      disabled={{@disabled}}
    />
    <div class="query-ai-prompt__actions">
      <DButton
        @action={{@onRegenerate}}
        @icon="arrows-rotate"
        @label={{or @actionLabel "explorer.ai.regenerate"}}
        @disabled={{@regenerateDisabled}}
        @isLoading={{@generating}}
        aria-busy={{@generating}}
        class={{dConcatClass
          (or @actionClass "btn-default")
          "query-ai-prompt__regenerate"
        }}
      />
    </div>
  </div>
</template>;

export default QueryAiPrompt;
