<<<<<<< HEAD
<<<<<<< HEAD
<div class="empty-state">
  <span class="empty-state-title">
    {{i18n "user_menu.no_chat_notifications_title"}}
  </span>
  <div class="empty-state-body">
    <p>
      {{html-safe
        (i18n
          "user_menu.no_chat_notifications_body"
          preferencesUrl=(get-url "/my/preferences/notifications")
        )
      }}
    </p>
  </div>
</div>
=======
import templateOnly from "@ember/component/template-only";

export default templateOnly();
>>>>>>> a9ddbde3f6 (DEV: [gjs-codemod] renamed js to gjs)
=======
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
>>>>>>> e41897a306 (DEV: [gjs-codemod] Convert final core components/routes to gjs)
