import getUrl from "discourse/helpers/get-url";
import htmlSafe from "discourse/helpers/html-safe";
import { i18n } from "discourse-i18n";

const ChatNotificationsListEmptyState = <template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{i18n "user_menu.no_chat_notifications_title"}}
    </span>
    <div class="empty-state-body">
      <p>
        {{htmlSafe
          (i18n
            "user_menu.no_chat_notifications_body"
            preferencesUrl=(getUrl "/my/preferences/notifications")
          )
        }}
      </p>
    </div>
  </div>
</template>;

export default ChatNotificationsListEmptyState;
