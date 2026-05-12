import { trustHTML } from "@ember/template";
import getUrl from "discourse/lib/get-url";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const NotificationsListEmptyState = <template>
  <DEmptyState
    @title={{i18n "user.no_notifications_title"}}
    @body={{trustHTML
      (i18n
        "user.no_notifications_body"
        icon=(dIcon "bell")
        preferencesUrl=(getUrl "/my/preferences/notifications")
      )
    }}
  />
</template>;

export default NotificationsListEmptyState;
