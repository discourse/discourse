import i18n from "discourse/helpers/i18n";
import htmlSafe from "discourse/helpers/html-safe";
const OtherNotificationsListEmptyState = <template><div class="empty-state">
  <span class="empty-state-title">
    {{i18n "user.no_other_notifications_title"}}
  </span>
  <div class="empty-state-body">
    <p>
      {{htmlSafe (i18n "user.no_other_notifications_body")}}
    </p>
  </div>
</div></template>;
export default OtherNotificationsListEmptyState;