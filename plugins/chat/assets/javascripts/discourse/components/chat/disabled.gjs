import getUrl from "discourse/lib/get-url";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";
import ChatZero from "../svg/chat-zero";

const ChatDisabled = <template>
  <div class="chat-disabled">
    <DEmptyState
      @body={{i18n "chat.disabled.body"}}
      @ctaHref={{getUrl "/my/preferences/chat"}}
      @ctaIcon="gear"
      @ctaLabel={{i18n "chat.disabled.cta"}}
      @identifier="chat-disabled"
      @svgContent={{ChatZero}}
      @title={{i18n "chat.disabled.title"}}
    />
  </div>
</template>;

export default ChatDisabled;
