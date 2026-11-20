import { on } from "@ember/modifier";
import routeAction from "discourse/helpers/route-action";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <button
    class="ai-bot-anonymous-card"
    type="button"
    {{on "click" (routeAction "showLogin")}}
  >
    <span class="ai-bot-anonymous-card__icon">
      {{dIcon "lock"}}
    </span>
    <span class="ai-bot-anonymous-card__title">
      {{i18n "discourse_ai.ai_bot.conversations.preview.title"}}
    </span>
    <span class="ai-bot-anonymous-card__body">
      {{i18n "discourse_ai.ai_bot.conversations.preview.body"}}
    </span>
  </button>
</template>
