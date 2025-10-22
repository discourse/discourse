import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

const AiHelperLoading = <template>
  <div class="ai-helper-loading">
    <div class="dot-falling"></div>
    <span>
      {{i18n "discourse_ai.ai_helper.context_menu.loading"}}
    </span>
    <DButton
      @icon="xmark"
      @title="discourse_ai.ai_helper.context_menu.cancel"
      @action={{@cancel}}
      class="btn-flat cancel-request"
    />
  </div>
</template>;

export default AiHelperLoading;
