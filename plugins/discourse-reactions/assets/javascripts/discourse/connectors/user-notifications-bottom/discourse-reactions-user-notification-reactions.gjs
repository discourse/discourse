import Component from "@ember/component";
import { LinkTo } from "@ember/routing";
import { classNames, tagName } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

@tagName("li")
@classNames(
  "user-notifications-bottom-outlet",
  "discourse-reactions-user-notification-reactions"
)
export default class DiscourseReactionsUserNotificationReactions extends Component {
  <template>
    {{#if this.siteSettings.discourse_reactions_enabled}}
      <LinkTo @route="userNotifications.reactionsReceived">
        {{icon "far-face-smile"}}
        <span>{{i18n "discourse_reactions.reactions_title"}}</span>
      </LinkTo>
    {{/if}}
  </template>
}
