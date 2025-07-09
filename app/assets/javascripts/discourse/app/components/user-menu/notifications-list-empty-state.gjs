import { htmlSafe } from "@ember/template";
import EmptyState from "discourse/components/empty-state";
import icon from "discourse/helpers/d-icon";
import getUrl from "discourse/helpers/get-url";
import { i18n } from "discourse-i18n";

const NotificationsListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_notifications_title"}}
    @body={{htmlSafe
      (i18n
        "user.no_notifications_body"
        icon=(icon "bell")
        preferencesUrl=(getUrl "/my/preferences/notifications")
      )
    }}
  />
</template>;

export default NotificationsListEmptyState;
