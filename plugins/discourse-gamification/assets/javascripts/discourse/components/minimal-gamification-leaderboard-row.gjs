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

  /**
   * Whether to render the rank cell on the left side of the row.
   * Defaults to `true` to preserve the original sidebar look.
   *
   * @returns {boolean}
   */
  get showRank() {
    return this.args.showRank ?? true;
  }

  /**
   * Avatar size passed to `dAvatar`. Accepts the standard Discourse
   * avatar size keywords (`small`, `medium`, `large`).
   *
   * @returns {string}
   */
  get avatarSize() {
    return this.args.avatarSize || "small";
  }

  <template>
    <div
      id="leaderboard-user-{{@rank.id}}"
      class={{dConcatClass "user" (if @rank.isCurrentUser "user-highlight")}}
    >
      {{#if this.showRank}}
        <div class={{dConcatClass "user__rank" (if @rank.topRanked "-winner")}}>
          {{#if @rank.topRanked}}
            {{dIcon "crown"}}
          {{else}}
            {{sum @index 1}}
          {{/if}}
        </div>
      {{/if}}
      <div
        role="button"
        data-user-card={{@rank.username}}
        class="user__avatar clickable"
      >
        {{dAvatar @rank imageSize=this.avatarSize}}

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
