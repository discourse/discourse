import getUrl from "discourse/lib/get-url";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";
import ChatZero from "../svg/chat-zero";

const ChatDisabled = <template>
  <div class="chat-disabled">
    <DEmptyState
      @identifier="chat-disabled"
      @svgContent={{ChatZero}}
      @title={{i18n "chat.disabled.title"}}
      @body={{i18n "chat.disabled.body"}}
      @ctaLabel={{i18n "chat.disabled.cta"}}
      @ctaHref={{getUrl "/my/preferences/chat"}}
      @ctaIcon="gear"
    />
  </div>
</template>;

export default ChatDisabled;
