import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import { block } from "discourse/blocks";
import avatar from "discourse/helpers/avatar";
import dIcon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import { ajax } from "discourse/lib/ajax";
import { and, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

@block("leaderboard")
export default class BlockLeaderboard extends Component {
  @tracked notTop10 = true;
  @tracked model = null;

  <template>
    <div class="block-leaderboard__layout">
      {{! Header }}
      <div class="block-leaderboard__header">
        <LinkTo
          @route="gamificationLeaderboard.byName"
          @model={{this.model.leaderboard.id}}
        >
          <h2 class="block-leaderboard__title">
            {{#if this.titleIcon}}
              {{dIcon this.titleIcon}}
            {{/if}}
            {{this.leaderboardName}}
          </h2>
        </LinkTo>
      </div>
      {{! List }}
      <div class="block-leaderboard__list">
        <div class="block-leaderboard__list-header">
          <span>{{i18n "gamification.leaderboard.rank"}}</span>
          <span>{{dIcon "award"}}{{i18n "gamification.score"}}</span>
        </div>
        <div class="block-leaderboard__list-body">
          {{#if (and this.currentUserRanking.user this.notTopTen)}}
            <div class="user --self">
              <div class="user__rank">{{this.currentUserRanking.position}}</div>
              <div class="user__name">{{i18n "gamification.you"}}</div>
              <div class="user__score">
                {{number this.currentUserRanking.user.total_score}}
              </div>
            </div>
          {{/if}}
          {{! Users }}
          {{#each this.ranking as |rank index|}}
            <div
              class="user__row {{if rank.isCurrentUser '--highlight'}}"
              id="leaderboard-user-{{rank.id}}"
            >
              <div class="user__rank {{if rank.topRanked '--winner'}}">
                {{#if rank.topRanked}}
                  {{dIcon "crown"}}
                {{else}}
                  {{this.displayRank index}}
                {{/if}}
              </div>
              <div
                class="user__avatar clickable"
                role="button"
                data-user-card={{rank.username}}
              >
                {{avatar rank imageSize=this.avatarSize}}
                {{#if rank.isCurrentUser}}
                  <span class="user__name">{{i18n "gamification.you"}}</span>
                {{else}}
                  <span class="user__name">
                    {{#if this.siteSettings.prioritize_username_in_ux}}
                      {{rank.username}}
                    {{else}}
                      {{or rank.name rank.username}}
                    {{/if}}
                  </span>
                {{/if}}
              </div>
              <div class="user__score">
                {{number rank.total_score}}
              </div>
            </div>
          {{/each}}
        </div>
      </div>
    </div>
  </template>

  constructor() {
    super(...arguments);
    this.avatarSize = this.args?.avatar || "medium";
    this.titleIcon = this.args?.icon;
    const count = this.args?.count || 10;
    const data = {
      user_limit: count,
    };
    const leaderboardId = this.args?.leaderboardId || null;
    const endpoint = leaderboardId
      ? `/leaderboard/${leaderboardId}`
      : "/leaderboard";
    ajax(endpoint, { data }).then((model) => {
      this.model = model;
    });
  }

  get leaderboardName() {
    return this.args?.title || this.model?.leaderboard.name;
  }

  get currentUserRanking() {
    const user = this.model?.personal;
    if (user) {
      this.notTop10 = user.position > 10;
    }
    return user || null;
  }

  get ranking() {
    this.model?.users?.forEach((user) => {
      if (user.id === this.model.personal?.user?.id) {
        user.isCurrentUser = "true";
      }
      if (this.model.users.indexOf(user) === 0) {
        user.topRanked = true;
      }
    });
    return this.model?.users;
  }

  displayRank(index) {
    return index + 1;
  }
}
