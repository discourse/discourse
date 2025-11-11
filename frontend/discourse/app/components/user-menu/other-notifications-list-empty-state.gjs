import { htmlSafe } from "@ember/template";
import EmptyState from "discourse/components/empty-state";
import { i18n } from "discourse-i18n";

const OtherNotificationsListEmptyState = <template>
  <EmptyState
    @title={{i18n "user.no_other_notifications_title"}}
    @body={{htmlSafe (i18n "user.no_other_notifications_body")}}
  />
</template>;

export default OtherNotificationsListEmptyState;
