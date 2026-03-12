import { trustHTML } from "@ember/template";
import getUrl from "discourse/lib/get-url";
import EmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";

const ChatNotificationsListEmptyState = <template>
  <EmptyState
    @title={{i18n "user_menu.no_chat_notifications_title"}}
    @body={{trustHTML
      (i18n
        "user_menu.no_chat_notifications_body"
        preferencesUrl=(getUrl "/my/preferences/notifications")
      )
    }}
  />
</template>;

export default ChatNotificationsListEmptyState;
