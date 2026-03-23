import { LinkTo } from "@ember/routing";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

const DiscourseBoostsUserNotificationBoosts = <template>
  <li
    class="user-notifications-bottom-outlet discourse-boosts-user-notification-boosts"
    ...attributes
  >
    <LinkTo @route="userNotifications.boostsReceived">
      {{icon "rocket"}}
      <span>{{i18n "discourse_boosts.boosts_title"}}</span>
    </LinkTo>
  </li>
</template>;

export default DiscourseBoostsUserNotificationBoosts;
