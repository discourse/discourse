import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import fullnumber from "../helpers/fullnumber";
import MinimalGamificationLeaderboardRow from "./minimal-gamification-leaderboard-row";

export default class extends Component {
  @service site;

  @tracked model;

  constructor() {
    super(...arguments);

    // id is used by discourse-right-sidebar-blocks theme component
    const endpoint = this.args.id
      ? `/leaderboard/${this.args.id}`
      : "/leaderboard";

    ajax(endpoint, { data: { user_limit: this.args.count || 10 } }).then(
      (model) => {
        for (const user of model.users) {
          if (user.id === model.personal?.user?.id) {
            user.isCurrentUser = "true";
          }
        }

        if (model.users[0]) {
          model.users[0].topRanked = true;
        }

        this.model = model;
      }
    );
  }

  get notTop10() {
    return this.model?.personal?.position > 10;
  }

  <template>
    <div class="leaderboard -minimal">
      <div class="page__header">
        <LinkTo
          @route="gamificationLeaderboard.byName"
          @model={{this.model.leaderboard.id}}
        >
          <h3 class="page__title">{{this.model.leaderboard.name}}</h3>
        </LinkTo>
      </div>

      <div class="ranking-col-names">
        <span>{{i18n "gamification.leaderboard.rank"}}</span>
        <span>{{icon "award"}}{{i18n "gamification.score"}}</span>
      </div>

      <div class="ranking-col-names__sticky-border"></div>

      {{#if this.notTopTen}}
        <div class="user -self">
          <div class="user__rank">{{this.model.personal.position}}</div>
          <div class="user__name">{{i18n "gamification.you"}}</div>
          <div class="user__score">
            {{#if this.site.mobileView}}
              {{number this.model.personal.user.total_score}}
            {{else}}
              {{fullnumber this.model.personal.user.total_score}}
            {{/if}}
          </div>
        </div>
      {{/if}}

      {{#each this.model.users as |rank index|}}
        <MinimalGamificationLeaderboardRow @rank={{rank}} @index={{index}} />
      {{/each}}
    </div>
  </template>
}
