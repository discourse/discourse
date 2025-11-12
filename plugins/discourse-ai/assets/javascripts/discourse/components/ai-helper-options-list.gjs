import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { PLATFORM_KEY_MODIFIER } from "discourse/lib/keyboard-shortcuts";
import { translateModKey } from "discourse/lib/utilities";
import { and, eq } from "discourse/truth-helpers";
import AiHelperCustomPrompt from "../components/ai-helper-custom-prompt";

export default class AiHelperOptionsList extends Component {
  @service site;

  get showShortcut() {
    return this.site.desktopView && this.args.shortcutVisible;
  }

  get shortcut() {
    return translateModKey(`${PLATFORM_KEY_MODIFIER} alt p`);
  }

  <template>
    <ul class="ai-helper-options">
      {{#each @options as |option|}}
        {{#if (eq option.name "custom_prompt")}}
          <AiHelperCustomPrompt
            @value={{@customPromptValue}}
            @promptArgs={{option}}
            @submit={{@performAction}}
          />
        {{else}}
          <li data-name={{option.translated_name}} data-value={{option.name}}>
            <DButton
              @icon={{option.icon}}
              @translatedLabel={{option.translated_name}}
              @action={{fn @performAction option}}
              data-name={{option.name}}
              class="ai-helper-options__button"
            >
              {{#if (and (eq option.name "proofread") this.showShortcut)}}
                <kbd class="shortcut">{{this.shortcut}}</kbd>
              {{/if}}
            </DButton>
          </li>
        {{/if}}
      {{/each}}
    </ul>
  </template>
}
