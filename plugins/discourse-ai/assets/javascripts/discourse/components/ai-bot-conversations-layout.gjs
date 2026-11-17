import PluginOutlet from "discourse/components/plugin-outlet";
import bodyClass from "discourse/helpers/body-class";
import lazyHash from "discourse/helpers/lazy-hash";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="ai-bot-conversations" ...attributes>
    {{bodyClass "ai-bot-conversations-page"}}

    <div class="ai-bot-conversations__content-wrapper">
      <div class="ai-bot-conversations__title">
        {{dIcon "far-discobot"}}
        {{i18n "discourse_ai.ai_bot.conversations.header"}}
      </div>
      <PluginOutlet
        @name="ai-bot-conversations-above-input"
        @outletArgs={{lazyHash updateInput=@updateInput submit=@submit}}
      />
      <div class="ai-bot-conversations__input-container">
        {{yield}}
      </div>

      <p class="ai-disclaimer">
        {{i18n "discourse_ai.ai_bot.conversations.disclaimer"}}
      </p>

      {{yield to="footer"}}
    </div>
  </div>
</template>
