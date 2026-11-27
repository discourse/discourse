import Component from "@glimmer/component";
import { service } from "@ember/service";

export default class AiChatModelLabel extends Component {
  @service siteSettings;

  <template>
    {{#if
      (and
        this.siteSettings.ai_bot_show_model_name @outletArgs.message.aiLlmName
      )
    }}
      <span class="ai-chat-message__model">
        {{@outletArgs.message.aiLlmName}}
      </span>
    {{/if}}
  </template>
}
