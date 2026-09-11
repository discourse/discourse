import { trustHTML } from "@ember/template";
import DEmptyState from "discourse/ui-kit/d-empty-state";
import { i18n } from "discourse-i18n";

const OtherNotificationsListEmptyState = <template>
  <DEmptyState
    @body={{trustHTML (i18n "user.no_other_notifications_body")}}
    @title={{i18n "user.no_other_notifications_title"}}
  />
</template>;

export default OtherNotificationsListEmptyState;
