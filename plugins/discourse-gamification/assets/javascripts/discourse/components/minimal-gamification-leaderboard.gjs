import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fetchLeaderboard } from "../lib/leaderboard";
import MinimalGamificationLeaderboardView from "./minimal-gamification-leaderboard-view";

/**
 * Self-fetching compact leaderboard for standalone use. The base usage is two
 * args (`id`, `count`) — kept as-is for backwards compatibility with the
 * `discourse-right-sidebar-blocks` theme. It fetches on construct (via the
 * shared `fetchLeaderboard`) and delegates rendering to the pure
 * `MinimalGamificationLeaderboardView`; the block variant resolves the same
 * fetch through the blocks data layer instead.
 */
export default class extends Component {
  @tracked model;

  constructor() {
    super(...arguments);

    fetchLeaderboard({
      id: this.args.id,
      count: this.args.count,
      period: this.args.period,
    }).then((model) => (this.model = model));
  }

  <template>
    {{#if this.model}}
      <MinimalGamificationLeaderboardView
        @model={{this.model}}
        @title={{@title}}
        @titleIcon={{@titleIcon}}
        @showColumnHeaders={{@showColumnHeaders}}
        @showRank={{@showRank}}
        @avatarSize={{@avatarSize}}
        @showFooterLink={{@showFooterLink}}
        @footerLinkLabel={{@footerLinkLabel}}
      />
    {{/if}}
  </template>
}
