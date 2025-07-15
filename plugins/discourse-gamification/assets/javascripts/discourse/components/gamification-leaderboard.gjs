import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import PeriodChooser from "select-kit/components/period-chooser";
import fullnumber from "../helpers/fullnumber";
import GamificationLeaderboardRow from "./gamification-leaderboard-row";
import LeaderboardInfo from "./modal/leaderboard-info";

export const LEADERBOARD_PERIODS = [
  "all_time",
  "yearly",
  "quarterly",
  "monthly",
  "weekly",
  "daily",
];
function periodString(periodValue) {
  switch (periodValue) {
    case 0:
      return "all";
    case 1:
      return "yearly";
    case 2:
      return "quarterly";
    case 3:
      return "monthly";
    case 4:
      return "weekly";
    case 5:
      return "daily";
    default:
      return "all";
  }
}

@tagName("")
export default class GamificationLeaderboard extends Component {
  @service router;
  @service modal;

  eyelineSelector = ".user";
  page = 1;
  loading = false;
  canLoadMore = true;
  period = "all";

  init() {
    super.init(...arguments);
    const default_leaderboard_period = periodString(
      this.model.leaderboard.default_period
    );
    this.set("period", default_leaderboard_period);
  }

  @discourseComputed("model.reason")
  isNotReady(reason) {
    return reason !== undefined;
  }

  @discourseComputed("model.users")
  currentUserRanking() {
    const user = this.model.personal;
    return user || null;
  }

  @discourseComputed("model.users")
  winners(users) {
    return users.slice(0, 3);
  }

  @discourseComputed("model.users.[]")
  ranking(users) {
    users.forEach((user) => {
      if (user.id === this.currentUser?.id) {
        user.isCurrentUser = "true";
      }
    });
    return users.slice(3);
  }

  @action
  showLeaderboardInfo() {
    this.modal.show(LeaderboardInfo);
  }

  @action
  loadMore() {
    if (this.loading || !this.canLoadMore) {
      return;
    }

    this.set("loading", true);

    return ajax(
      `/leaderboard/${this.model.leaderboard.id}?page=${this.page}&period=${this.period}`
    )
      .then((result) => {
        if (result.users.length === 0) {
          this.set("canLoadMore", false);
        }
        this.set("page", (this.page += 1));
        this.set("model.users", this.model.users.concat(result.users));
      })
      .finally(() => this.set("loading", false))
      .catch(popupAjaxError);
  }

  @action
  changePeriod(period) {
    this.set("period", period);
    return ajax(
      `/leaderboard/${this.model.leaderboard.id}?period=${this.period}`
    )
      .then((result) => {
        if (result.users.length === 0) {
          this.set("canLoadMore", false);
          this.set("model.reason", result.reason);
        }
        this.set("page", 1);
        this.set("model.users", result.users);
        this.set("model.personal", result.personal);
      })
      .finally(() => this.set("loading", false))
      .catch(popupAjaxError);
  }

  @action
  refresh() {
    this.router.refresh();
  }

  <template>
    <div class="leaderboard">
      <div class="page__header">
        <h1 class="page__title">{{this.model.leaderboard.name}}</h1>
        <DButton
          @action={{this.showLeaderboardInfo}}
          class="-ghost"
          @icon="circle-info"
          @label={{unless this.site.mobileView "gamification.leaderboard.info"}}
        />
      </div>

      <div class="leaderboard__controls">
        <PeriodChooser
          @period={{this.period}}
          @action={{this.changePeriod}}
          @fullDay={{false}}
          @options={{hash
            disabled=this.model.leaderboard.period_filter_disabled
          }}
          class="leaderboard__period-chooser"
        />
        {{#if this.currentUser.staff}}
          <a href="/admin/plugins/gamification" class="leaderboard__settings">
            {{icon "gear"}}
            {{unless
              this.site.mobileView
              (i18n "gamification.leaderboard.link_to_settings")
            }}
          </a>
        {{/if}}
      </div>

      {{#if this.isNotReady}}
        <div class="leaderboard__not-ready">
          <p>{{this.model.reason}}</p>
          <DButton
            @icon="arrows-rotate"
            @label="gamification.leaderboard.refresh"
            @action={{this.refresh}}
            class="btn-primary refresh"
          />
        </div>
      {{else}}
        <div class="podium__wrapper">
          <div class="podium">
            {{#each this.winners as |winner|}}
              <div class="winner -position{{winner.position}}">
                <div class="winner__crown">{{icon "crown"}}</div>
                <div
                  class="winner__avatar clickable"
                  role="button"
                  data-user-card={{winner.username}}
                >
                  {{avatar winner imageSize="huge"}}
                  <div class="winner__rank">
                    <span>{{winner.position}}</span>
                  </div>
                </div>
                <div class="winner__name">
                  {{#if this.siteSettings.prioritize_username_in_ux}}
                    {{winner.username}}
                  {{else}}
                    {{or winner.name winner.username}}
                  {{/if}}
                </div>
                <div class="winner__score">{{fullnumber
                    winner.total_score
                  }}</div>
              </div>
            {{/each}}
          </div>
        </div>

        <div class="ranking">
          <div class="ranking-col-names">
            <span>{{i18n "gamification.leaderboard.rank"}}</span>
            <span>{{icon "award"}}{{i18n "gamification.score"}}</span>
          </div>
          <div class="ranking-col-names__sticky-border"></div>
          {{#if this.currentUserRanking.user}}
            <div class="user -self">
              <div class="user__rank">{{this.currentUserRanking.position}}</div>
              <div class="user__name">{{i18n "gamification.you"}}</div>
              <div class="user__score">
                {{#if this.site.mobileView}}
                  {{number this.currentUserRanking.user.total_score}}
                {{else}}
                  {{fullnumber this.currentUserRanking.user.total_score}}
                {{/if}}
              </div>
            </div>
          {{/if}}

          <LoadMore @action={{this.loadMore}}>
            {{#each this.ranking as |rank index|}}
              <GamificationLeaderboardRow @rank={{rank}} @index={{index}} />
            {{/each}}
          </LoadMore>
          <ConditionalLoadingSpinner @condition={{this.loading}} />
        </div>
      {{/if}}
    </div>
  </template>
}
