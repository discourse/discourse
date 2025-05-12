import { htmlSafe } from "@ember/template";
import { i18n } from "discourse-i18n";

const OtherNotificationsListEmptyState = <template>
  <div class="empty-state">
    <span class="empty-state-title">
      {{i18n "user.no_other_notifications_title"}}
    </span>
    <div class="empty-state-body">
      <p>
        {{htmlSafe (i18n "user.no_other_notifications_body")}}
      </p>
    </div>
  </div>
</template>;

export default OtherNotificationsListEmptyState;
