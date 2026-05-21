import Component from "@glimmer/component";
import { service } from "@ember/service";
import { or } from "discourse/truth-helpers";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import sum from "../helpers/sum";

export default class MinimalGamificationLeaderboardRow extends Component {
  @service siteSettings;

  <template>
    <div
      id="leaderboard-user-{{@rank.id}}"
      class={{dConcatClass "user" (if @rank.isCurrentUser "user-highlight")}}
    >
      <div class={{dConcatClass "user__rank" (if @rank.topRanked "-winner")}}>
        {{#if @rank.topRanked}}
          {{dIcon "crown"}}
        {{else}}
          {{sum @index 1}}
        {{/if}}
      </div>
      <div
        role="button"
        data-user-card={{@rank.username}}
        class="user__avatar clickable"
      >
        {{dAvatar @rank imageSize="small"}}

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
        {{dNumber @rank.total_score}}
      </div>
    </div>
  </template>
}
