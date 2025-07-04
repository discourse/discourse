import EmptyState from "discourse/components/empty-state";
import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

const ChatNotificationsListEmptyState = <template>
  <EmptyState
    @title={{i18n "user_menu.no_chat_notifications_title"}}
    @body={{htmlSafe
      (i18n
        "user_menu.no_chat_notifications_body"
        preferencesUrl=(getUrl "/my/preferences/notifications")
      )
    }}
  />
</template>;

export default ChatNotificationsListEmptyState;
