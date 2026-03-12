import { trustHTML } from "@ember/template";
import getUrl from "discourse/lib/get-url";
import EmptyState from "discourse/ui-kit/d-empty-state";
import icon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const NotificationsListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_notifications_title"}}
    @body={{trustHTML
      (i18n
        "user.no_notifications_body"
        icon=(icon "bell")
        preferencesUrl=(getUrl "/my/preferences/notifications")
      )
    }}
  />
</template>;

export default NotificationsListEmptyState;
