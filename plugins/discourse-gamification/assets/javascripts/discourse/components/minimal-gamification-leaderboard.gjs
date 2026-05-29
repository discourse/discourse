import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import fullnumber from "../helpers/fullnumber";
import MinimalGamificationLeaderboardRow from "./minimal-gamification-leaderboard-row";

/**
 * Compact sidebar leaderboard. The base usage is two args (`id`,
 * `count`) — kept as-is for backwards compatibility with the
 * `discourse-right-sidebar-blocks` theme. Additional optional args
 * customize the rendering for visual-editor block usage; defaults
 * preserve the current look.
 */
export default class extends Component {
  @service site;

  @tracked model;

  constructor() {
    super(...arguments);

    // id is used by discourse-right-sidebar-blocks theme component
    const endpoint = this.args.id
      ? `/leaderboard/${this.args.id}`
      : "/leaderboard";

    const data = { user_limit: this.args.count || 10 };
    if (this.args.period) {
      data.period = this.args.period;
    }

    ajax(endpoint, { data }).then((model) => {
      for (const user of model.users) {
        if (user.id === model.personal?.user?.id) {
          user.isCurrentUser = "true";
        }
      }

      if (model.users[0]) {
        model.users[0].topRanked = true;
      }

      this.model = model;
    });
  }

  /**
   * Whether the current user sits outside the top ten and should be
   * shown as a pinned "you" row above the ranked list.
   *
   * @returns {boolean}
   */
  get notTopTen() {
    return this.model?.personal?.position > 10;
  }

  /**
   * Whether to render the `Rank | Score` column header row. Defaults
   * to `true` to preserve the original sidebar look.
   *
   * @returns {boolean}
   */
  get showColumnHeaders() {
    return this.args.showColumnHeaders ?? true;
  }

  /**
   * Whether to render the rank column (both the header and the
   * per-row rank cell). Defaults to `true`.
   *
   * @returns {boolean}
   */
  get showRank() {
    return this.args.showRank ?? true;
  }

  /**
   * Avatar size passed down to each row. Accepts the standard
   * Discourse avatar size keywords (`small`, `medium`, `large`).
   *
   * @returns {string}
   */
  get avatarSize() {
    return this.args.avatarSize || "small";
  }

  /**
   * The title shown in the leaderboard header. Falls back to the
   * leaderboard's own name when no override is provided.
   *
   * @returns {string | undefined}
   */
  get displayedTitle() {
    return this.args.title || this.model?.leaderboard?.name;
  }

  /**
   * Label for the optional "view all" footer link. Falls back to a
   * localized default when no override is provided.
   *
   * @returns {string}
   */
  get footerLinkLabel() {
    return (
      this.args.footerLinkLabel ||
      i18n("gamification.leaderboard.block.footer_link_default_label")
    );
  }

  <template>
    <div class="leaderboard -minimal">
      <div class="page__header">
        <LinkTo
          @route="gamificationLeaderboard.byName"
          @model={{this.model.leaderboard.id}}
        >
          <h3 class="page__title">
            {{#if @titleIcon}}
              {{dIcon @titleIcon}}
            {{/if}}
            {{this.displayedTitle}}
          </h3>
        </LinkTo>
      </div>

      {{#if this.showColumnHeaders}}
        <div class="ranking-col-names">
          {{#if this.showRank}}
            <span>{{i18n "gamification.leaderboard.rank"}}</span>
          {{/if}}
          <span>{{dIcon "award"}}{{i18n "gamification.score"}}</span>
        </div>

        <div class="ranking-col-names__sticky-border"></div>
      {{/if}}

      {{#if this.notTopTen}}
        <div class="user -self">
          {{#if this.showRank}}
            <div class="user__rank">{{this.model.personal.position}}</div>
          {{/if}}
          <div class="user__name">{{i18n "gamification.you"}}</div>
          <div class="user__score">
            {{#if this.site.mobileView}}
              {{dNumber this.model.personal.user.total_score}}
            {{else}}
              {{fullnumber this.model.personal.user.total_score}}
            {{/if}}
          </div>
        </div>
      {{/if}}

      {{#each this.model.users as |rank index|}}
        <MinimalGamificationLeaderboardRow
          @rank={{rank}}
          @index={{index}}
          @showRank={{this.showRank}}
          @avatarSize={{this.avatarSize}}
        />
      {{/each}}

      {{#if @showFooterLink}}
        <div class="leaderboard__footer">
          <LinkTo
            class="leaderboard__footer-link"
            @route="gamificationLeaderboard.byName"
            @model={{this.model.leaderboard.id}}
          >
            {{this.footerLinkLabel}}
          </LinkTo>
        </div>
      {{/if}}
    </div>
  </template>
}
