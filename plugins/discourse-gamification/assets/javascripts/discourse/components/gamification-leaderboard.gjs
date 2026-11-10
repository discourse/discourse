import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action, get, set } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { resettableTracked } from "discourse/lib/tracked-tools";
import PeriodChooser from "discourse/select-kit/components/period-chooser";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import fullnumber from "../helpers/fullnumber.js";
import GamificationLeaderboardRow from "./gamification-leaderboard-row.gjs";
import LeaderboardInfo from "./modal/leaderboard-info.gjs";

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

export default class GamificationLeaderboard extends Component {
  @service currentUser;
  @service modal;
  @service router;
  @service site;
  @service siteSettings;

  @tracked loading = false;
  @resettableTracked
  period = periodString(this.args.model.leaderboard.default_period);

  page = 1;
  canLoadMore = true;

  get isNotReady() {
    return get(this.args.model, "reason") !== undefined;
  }

  get currentUserRanking() {
    return get(this.args.model, "personal") || null;
  }

  get winners() {
    return get(this.args.model, "users")?.slice(0, 3);
  }

  get ranking() {
    const users = get(this.args.model, "users");
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

    this.loading = true;
    const model = this.args.model;

    return ajax(
      `/leaderboard/${model.leaderboard.id}?page=${this.page}&period=${this.period}`
    )
      .then((result) => {
        if (result.users.length === 0) {
          this.canLoadMore = false;
        }
        this.page += 1;
        set(model, "users", model.users.concat(result.users));
      })
      .finally(() => (this.loading = false))
      .catch(popupAjaxError);
  }

  @action
  changePeriod(period) {
    this.period = period;
    const model = this.args.model;

    return ajax(`/leaderboard/${model.leaderboard.id}?period=${this.period}`)
      .then((result) => {
        if (result.users.length === 0) {
          this.canLoadMore = false;
          set(model, "reason", result.reason);
        }
        this.page = 1;
        set(model, "users", result.users);
        set(model, "personal", result.personal);
      })
      .finally(() => (this.loading = false))
      .catch(popupAjaxError);
  }

  @action
  refresh() {
    this.router.refresh();
  }

  <template>
    <div class="leaderboard">
      <div class="page__header">
        <h1 class="page__title">{{@model.leaderboard.name}}</h1>
        <DButton
          class="-ghost"
          @action={{this.showLeaderboardInfo}}
          @icon="circle-info"
          @label={{unless this.site.mobileView "gamification.leaderboard.info"}}
        />
      </div>

      <div class="leaderboard__controls">
        <PeriodChooser
          class="leaderboard__period-chooser"
          @action={{this.changePeriod}}
          @fullDay={{false}}
          @options={{hash disabled=@model.leaderboard.period_filter_disabled}}
          @period={{this.period}}
        />
        {{#if this.currentUser.staff}}
          <a
            class="leaderboard__settings"
            href={{getURL "/admin/plugins/gamification"}}
          >
            {{dIcon "gear"}}
            {{unless
              this.site.mobileView
              (i18n "gamification.leaderboard.link_to_settings")
            }}
          </a>
        {{/if}}
      </div>

      {{#if this.isNotReady}}
        <div class="leaderboard__not-ready">
          <p>{{@model.reason}}</p>
          <DButton
            class="btn-primary refresh"
            @action={{this.refresh}}
            @icon="arrows-rotate"
            @label="gamification.leaderboard.refresh"
          />
        </div>
      {{else}}
        <div class="podium__wrapper">
          <div class="podium">
            {{#each this.winners as |winner|}}
              <div class="winner -position{{winner.position}}">
                <div class="winner__crown">{{dIcon "crown"}}</div>
                <div
                  class="winner__avatar clickable"
                  data-user-card={{winner.username}}
                  role="button"
                >
                  {{dAvatar winner imageSize="huge"}}
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
            <span>{{dIcon "award"}}{{i18n "gamification.score"}}</span>
          </div>
          <div class="ranking-col-names__sticky-border"></div>
          {{#if this.currentUserRanking.user}}
            <div class="user -self">
              <div class="user__rank">{{this.currentUserRanking.position}}</div>
              <div class="user__name">{{i18n "gamification.you"}}</div>
              <div class="user__score">
                {{#if this.site.mobileView}}
                  {{dNumber this.currentUserRanking.user.total_score}}
                {{else}}
                  {{fullnumber this.currentUserRanking.user.total_score}}
                {{/if}}
              </div>
            </div>
          {{/if}}

          <DLoadMore @action={{this.loadMore}}>
            {{#each this.ranking as |rank index|}}
              <GamificationLeaderboardRow @index={{index}} @rank={{rank}} />
            {{/each}}
          </DLoadMore>
          <DConditionalLoadingSpinner @condition={{this.loading}} />
        </div>
      {{/if}}
    </div>
  </template>
}
