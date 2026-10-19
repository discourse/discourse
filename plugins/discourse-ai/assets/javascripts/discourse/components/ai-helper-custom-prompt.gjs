import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import withEventValue from "discourse/helpers/with-event-value";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class AiHelperCustomPrompt extends Component {
  @action
  handleSubmit(event) {
    event.preventDefault();
    if (!this.args.value?.length) {
      return;
    }
    this.args.submit(this.args.promptArgs);
  }

  <template>
    <form class="ai-custom-prompt" {{on "submit" this.handleSubmit}}>

      <input
        autofocus="autofocus"
        class="ai-custom-prompt__input"
        placeholder={{i18n
          "discourse_ai.ai_helper.context_menu.custom_prompt.placeholder"
        }}
        type="text"
        value={{@value}}
        {{on "input" (withEventValue (fn (mut @value)))}}
      />

      <DButton
        class="ai-custom-prompt__submit btn-primary"
        @action={{fn @submit @promptArgs}}
        @disabled={{not @value.length}}
        @icon="discourse-sparkles"
      />
    </form>
  </template>
}
