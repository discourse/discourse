// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import { i18n } from "discourse-i18n";
/** @type {import("discourse/plugins/discourse-gamification/discourse/components/minimal-gamification-leaderboard-view.gjs")} */
import MinimalGamificationLeaderboardView from "../components/minimal-gamification-leaderboard-view";
import { fetchLeaderboard } from "../lib/leaderboard";

const PERIODS = [
  "",
  "all",
  "yearly",
  "quarterly",
  "monthly",
  "weekly",
  "daily",
];
const AVATAR_SIZES = ["small", "medium", "large"];

/**
 * Block registration for the gamification leaderboard. Wraps the
 * existing `MinimalGamificationLeaderboard` (compact sidebar variant)
 * so authors can drop a leaderboard into any block-driven outlet.
 *
 * When `leaderboardId` is blank, the inner component falls back to the
 * site's default leaderboard via the parameterless `/leaderboard`
 * endpoint.
 */
@block("gamification:leaderboard", {
  displayName: "Gamification leaderboard",
  icon: "trophy",
  category: "Discourse data",
  description: "Compact sidebar leaderboard with top contributors and scores.",
  args: {
    leaderboardId: {
      type: "number",
      integer: true,
      min: 1,
      ui: {
        control: "number",
        label: i18n("gamification.leaderboard.block.leaderboard_id"),
        helpText: i18n("gamification.leaderboard.block.leaderboard_id_help"),
      },
    },
    count: {
      type: "number",
      default: 10,
      integer: true,
      min: 1,
      max: 25,
      ui: {
        control: "number",
        label: i18n("gamification.leaderboard.block.count"),
      },
    },
    title: {
      type: "string",
      default: "",
      ui: {
        label: i18n("gamification.leaderboard.block.title"),
        helpText: i18n("gamification.leaderboard.block.title_help"),
      },
    },
    titleIcon: {
      type: "string",
      default: "",
      ui: {
        control: "icon",
        label: i18n("gamification.leaderboard.block.title_icon"),
      },
    },
    period: {
      type: "string",
      default: "",
      enum: PERIODS,
      ui: {
        control: "select",
        label: i18n("gamification.leaderboard.block.period"),
        helpText: i18n("gamification.leaderboard.block.period_help"),
      },
    },
    showColumnHeaders: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("gamification.leaderboard.block.show_column_headers"),
      },
    },
    showRank: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("gamification.leaderboard.block.show_rank"),
      },
    },
    avatarSize: {
      type: "string",
      default: "small",
      enum: AVATAR_SIZES,
      ui: {
        control: "select",
        label: i18n("gamification.leaderboard.block.avatar_size"),
      },
    },
    showFooterLink: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("gamification.leaderboard.block.show_footer_link"),
      },
    },
    footerLinkLabel: {
      type: "string",
      default: "",
      ui: {
        label: i18n("gamification.leaderboard.block.footer_link_label"),
      },
    },
  },
  previewArgs: {
    count: 10,
    title: "Best Weekly Contributors",
    titleIcon: "trophy",
    period: "weekly",
    showColumnHeaders: false,
    showRank: false,
    showFooterLink: true,
    footerLinkLabel: "Show all",
  },
  data: {
    request: (args) => ({
      kind: "gamification-leaderboard",
      leaderboardId: args.leaderboardId,
      count: args.count ?? 10,
      period: args.period,
    }),
    resolve: (descriptor) =>
      fetchLeaderboard({
        id: descriptor.leaderboardId,
        count: descriptor.count,
        period: descriptor.period,
      }),
    skeleton: (args) => ({ variant: "rect", count: args.count ?? 10 }),
  },
})
export default class GamificationLeaderboardBlock extends Component {
  <template>
    <div class="gamification-leaderboard-block">
      {{! The leaderboard's title and footer derive from the fetched model, so
          the whole widget is the data region; the reserved-space skeleton (from
          the block's `skeleton` hint) covers it while loading. }}
      <@Data>
        <:content as |model|>
          <MinimalGamificationLeaderboardView
            @model={{model}}
            @title={{@title}}
            @titleIcon={{@titleIcon}}
            @showColumnHeaders={{@showColumnHeaders}}
            @showRank={{@showRank}}
            @avatarSize={{@avatarSize}}
            @showFooterLink={{@showFooterLink}}
            @footerLinkLabel={{@footerLinkLabel}}
          />
        </:content>
      </@Data>
    </div>
  </template>
}
