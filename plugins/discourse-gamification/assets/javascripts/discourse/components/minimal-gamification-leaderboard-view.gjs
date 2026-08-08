import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
import fullnumber from "../helpers/fullnumber";
import MinimalGamificationLeaderboardRow from "./minimal-gamification-leaderboard-row";

/**
 * Pure renderer for the compact sidebar leaderboard. Given a resolved
 * leaderboard `@model` plus display args, it renders the header, optional
 * column headers, the personal "you" row, the ranked rows, and the optional
 * footer. It does no fetching — the self-fetching
 * `MinimalGamificationLeaderboard` wrapper and the block both supply `@model`.
 */
export default class MinimalGamificationLeaderboardView extends Component {
  @service site;

  /**
   * Whether the current user sits outside the top ten and should be shown as a
   * pinned "you" row above the ranked list.
   *
   * @returns {boolean}
   */
  get notTopTen() {
    return this.args.model?.personal?.position > 10;
  }

  /**
   * Whether to render the `Rank | Score` column header row. Defaults to `true`
   * to preserve the original sidebar look.
   *
   * @returns {boolean}
   */
  get showColumnHeaders() {
    return this.args.showColumnHeaders ?? true;
  }

  /**
   * Whether to render the rank column (both the header and the per-row rank
   * cell). Defaults to `true`.
   *
   * @returns {boolean}
   */
  get showRank() {
    return this.args.showRank ?? true;
  }

  /**
   * Avatar size passed down to each row. Accepts the standard Discourse avatar
   * size keywords (`small`, `medium`, `large`).
   *
   * @returns {string}
   */
  get avatarSize() {
    return this.args.avatarSize || "small";
  }

  /**
   * The title shown in the header. Falls back to the leaderboard's own name
   * when no override is provided.
   *
   * @returns {string | undefined}
   */
  get displayedTitle() {
    return this.args.title || this.args.model?.leaderboard?.name;
  }

  /**
   * Label for the optional "view all" footer link. Falls back to a localized
   * default when no override is provided.
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
          @model={{@model.leaderboard.id}}
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
            <div class="user__rank">{{@model.personal.position}}</div>
          {{/if}}
          <div class="user__name">{{i18n "gamification.you"}}</div>
          <div class="user__score">
            {{#if this.site.mobileView}}
              {{dNumber @model.personal.user.total_score}}
            {{else}}
              {{fullnumber @model.personal.user.total_score}}
            {{/if}}
          </div>
        </div>
      {{/if}}

      {{#each @model.users as |rank index|}}
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
            @model={{@model.leaderboard.id}}
          >
            {{this.footerLinkLabel}}
          </LinkTo>
        </div>
      {{/if}}
    </div>
  </template>
}
