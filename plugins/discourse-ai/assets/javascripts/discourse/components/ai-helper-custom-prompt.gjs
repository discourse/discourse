import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import withEventValue from "discourse/helpers/with-event-value";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class AiHelperCustomPrompt extends Component {
  @action
  sendInput(event) {
    if (event.key !== "Enter") {
      return;
    }
    return this.args.submit(this.args.promptArgs);
  }

  <template>
    <div class="ai-custom-prompt">

      <input
        {{on "input" (withEventValue (fn (mut @value)))}}
        {{on "keydown" this.sendInput}}
        value={{@value}}
        placeholder={{i18n
          "discourse_ai.ai_helper.context_menu.custom_prompt.placeholder"
        }}
        class="ai-custom-prompt__input"
        type="text"
        autofocus="autofocus"
      />

      <DButton
        @icon="discourse-sparkles"
        @action={{fn @submit @promptArgs}}
        @disabled={{not @value.length}}
        class="ai-custom-prompt__submit btn-primary"
      />
    </div>
  </template>
}
