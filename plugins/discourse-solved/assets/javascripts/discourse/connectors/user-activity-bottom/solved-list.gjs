import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SolvedList extends Component {
  @service siteSettings;

  <template>
    {{#if this.siteSettings.solved_enabled}}
      <li class="user-activity-bottom-outlet solved-list">
        <LinkTo @route="userActivity.solved">
          {{icon "square-check"}}
          {{i18n "solved.title"}}
        </LinkTo>
      </li>
    {{/if}}
  </template>
}
