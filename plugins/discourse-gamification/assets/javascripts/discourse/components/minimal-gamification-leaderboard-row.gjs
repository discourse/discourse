import Component from "@glimmer/component";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import { i18n } from "discourse-i18n";
import sum from "../helpers/sum";

export default class MinimalGamificationLeaderboardRow extends Component {
  @service siteSettings;

  <template>
    <div
      id="leaderboard-user-{{@rank.id}}"
      class={{concatClass "user" (if @rank.isCurrentUser "user-highlight")}}
    >
      <div class={{concatClass "user__rank" (if @rank.topRanked "-winner")}}>
        {{#if @rank.topRanked}}
          {{icon "crown"}}
        {{else}}
          {{sum @index 1}}
        {{/if}}
      </div>
      <div
        role="button"
        data-user-card={{@rank.username}}
        class="user__avatar clickable"
      >
        {{avatar @rank imageSize="small"}}

        {{#if @rank.isCurrentUser}}
          <span class="user__name">{{i18n "gamification.you"}}</span>
        {{else}}
          <span class="user__name">
            {{#if this.siteSettings.prioritize_username_in_ux}}
              {{@rank.username}}
            {{else}}
              {{or @rank.name @rank.username}}
            {{/if}}
          </span>
        {{/if}}
      </div>

      <div class="user__score">
        {{number @rank.total_score}}
      </div>
    </div>
  </template>
}
