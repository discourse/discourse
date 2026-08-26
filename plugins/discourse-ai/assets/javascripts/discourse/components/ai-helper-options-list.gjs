import { fn } from "@ember/helper";
import { and, eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DShortcut from "discourse/ui-kit/d-shortcut";
import AiHelperCustomPrompt from "../components/ai-helper-custom-prompt";

const AiHelperOptionsList = <template>
  <ul class="ai-helper-options">
    {{#each @options as |option|}}
      {{#if (eq option.name "custom_prompt")}}
        <AiHelperCustomPrompt
          @value={{@customPromptValue}}
          @promptArgs={{option}}
          @submit={{@performAction}}
        />
      {{else if (and (eq option.name "proofread") @shortcutVisible)}}
        <li data-name={{option.translated_name}} data-value={{option.name}}>
          <DShortcut @keys="mod+alt+p" as |shortcut|>
            <DButton
              class="ai-helper-options__button"
              data-name={{option.name}}
              aria-keyshortcuts={{shortcut.aria}}
              @action={{fn @performAction option}}
              @icon={{option.icon}}
              @translatedLabel={{option.translated_name}}
            >
              <shortcut.Kbd class="shortcut" />
            </DButton>
          </DShortcut>
        </li>
      {{else}}
        <li data-name={{option.translated_name}} data-value={{option.name}}>
          <DButton
            class="ai-helper-options__button"
            data-name={{option.name}}
            @action={{fn @performAction option}}
            @icon={{option.icon}}
            @translatedLabel={{option.translated_name}}
          />
        </li>
      {{/if}}
    {{/each}}
  </ul>
</template>;

export default AiHelperOptionsList;
