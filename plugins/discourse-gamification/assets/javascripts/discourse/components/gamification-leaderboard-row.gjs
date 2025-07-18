import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { or } from "truth-helpers";
import avatar from "discourse/helpers/avatar";
import number from "discourse/helpers/number";
import fullnumber from "../helpers/fullnumber";

@tagName("")
export default class GamificationLeaderboardRow extends Component {
  rank = null;

  <template>
    <div
      class="user {{if this.rank.currentUser 'user-highlight'}}"
      id="leaderboard-user-{{this.rank.id}}"
    >
      <div class="user__rank">{{this.rank.position}}</div>
      <div
        class="user__avatar clickable"
        role="button"
        data-user-card={{this.rank.username}}
      >
        {{avatar this.rank imageSize="large"}}
        <span class="user__name">
          {{#if this.siteSettings.prioritize_username_in_ux}}
            {{this.rank.username}}
          {{else}}
            {{or this.rank.name this.rank.username}}
          {{/if}}
        </span>
      </div>
      <div class="user__score">
        {{#if this.site.mobileView}}
          {{number this.rank.total_score}}
        {{else}}
          {{fullnumber this.rank.total_score}}
        {{/if}}
      </div>
    </div>
  </template>
}
