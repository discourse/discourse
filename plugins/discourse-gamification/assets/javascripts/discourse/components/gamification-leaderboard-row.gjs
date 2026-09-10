import Component from "@glimmer/component";
import { service } from "@ember/service";
import { or } from "discourse/truth-helpers";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dNumber from "discourse/ui-kit/helpers/d-number";
import fullnumber from "../helpers/fullnumber";

export default class GamificationLeaderboardRow extends Component {
  @service site;
  @service siteSettings;

  <template>
    <div
      class="user {{if @rank.currentUser 'user-highlight'}}"
      id="leaderboard-user-{{@rank.id}}"
    >
      <div class="user__rank">{{@rank.position}}</div>
      <div
        class="user__avatar clickable"
        data-user-card={{@rank.username}}
        role="button"
      >
        {{dAvatar @rank imageSize="large"}}
        <span class="user__name">
          {{#if this.siteSettings.prioritize_username_in_ux}}
            {{@rank.username}}
          {{else}}
            {{or @rank.name @rank.username}}
          {{/if}}
        </span>
      </div>
      <div class="user__score">
        {{#if this.site.mobileView}}
          {{dNumber @rank.total_score}}
        {{else}}
          {{fullnumber @rank.total_score}}
        {{/if}}
      </div>
    </div>
  </template>
}
