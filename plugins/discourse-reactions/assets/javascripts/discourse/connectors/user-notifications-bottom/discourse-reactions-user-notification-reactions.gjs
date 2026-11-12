import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DiscourseReactionsUserNotificationReactions extends Component {
  @service siteSettings;

  <template>
    <li
      class="user-notifications-bottom-outlet discourse-reactions-user-notification-reactions"
      ...attributes
    >
      {{#if this.siteSettings.discourse_reactions_enabled}}
        <LinkTo @route="userNotifications.reactionsReceived">
          {{dIcon "far-face-smile"}}
          <span>{{i18n "discourse_reactions.reactions_title"}}</span>
        </LinkTo>
      {{/if}}
    </li>
  </template>
}
