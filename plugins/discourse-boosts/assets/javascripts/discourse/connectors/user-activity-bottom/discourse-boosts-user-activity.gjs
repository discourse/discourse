import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class DiscourseBoostsUserActivity extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.discourse_boosts_enabled}}
      <li class="user-activity-bottom-outlet discourse-boosts-user-activity">
        <LinkTo @route="userActivity.boosts">
          {{icon "rocket"}}
          <span>{{i18n "discourse_boosts.boosts_title"}}</span>
        </LinkTo>
      </li>
    {{/if}}
  </template>
}
