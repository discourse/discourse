// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { block, defineBlockDataSource } from "discourse/blocks";
import BlockPanel from "discourse/blocks/block-panel";
import getURL from "discourse/lib/get-url";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";
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

const gamificationLeaderboardDataSource = defineBlockDataSource({
  // A leaderboard without scored users resolves empty, so the block shows its
  // empty state instead of an empty list.
  resolve: async (descriptor) => {
    const model = await fetchLeaderboard({
      id: descriptor.leaderboardId,
      count: descriptor.count,
      period: descriptor.period,
    });
    return model.users.length ? model : null;
  },
});

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
  category: "community",
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
      default: true,
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
    source: gamificationLeaderboardDataSource,
    request: (args) => ({
      kind: "gamification-leaderboard",
      leaderboardId: args.leaderboardId,
      count: args.count ?? 10,
      period: args.period,
    }),
    skeleton: (args) => ({ rows: "user", count: args.count ?? 10 }),
  },
})
export default class GamificationLeaderboardBlock extends Component {
  @service siteSettings;

  // The header renders outside the data region, so the loaded leaderboard's
  // name reaches it once the rows have rendered.
  @tracked leaderboardName;

  rememberName = modifier((element, [name]) => {
    this.leaderboardName = name;
  });

  displayName = (user) =>
    this.siteSettings.prioritize_username_in_ux
      ? user.username
      : user.name || user.username;

  get title() {
    return (
      this.args.title ||
      this.leaderboardName ||
      i18n("gamification.leaderboard.block.default_title")
    );
  }

  get leaderboardUrl() {
    const id = this.args.leaderboardId;
    return getURL(id ? `/leaderboard/${id}` : "/leaderboard");
  }

  get footerLinkLabel() {
    return (
      this.args.footerLinkLabel ||
      i18n("gamification.leaderboard.block.footer_link_default_label")
    );
  }

  <template>
    <BlockPanel
      class="gamification-block-leaderboard"
      @Data={{@Data}}
      @icon={{@titleIcon}}
      @title={{this.title}}
    >
      <:content as |model|>
        {{#if @showColumnHeaders}}
          <div class="gamification-block-leaderboard__columns">
            {{#if @showRank}}
              <span>{{i18n "gamification.leaderboard.rank"}}</span>
            {{/if}}
            <span class="gamification-block-leaderboard__columns-score">{{i18n
                "gamification.score"
              }}</span>
          </div>
        {{/if}}
        <ol
          class="gamification-block-leaderboard__list"
          {{this.rememberName model.leaderboard.name}}
        >
          {{#each model.users as |user|}}
            <li class="gamification-block-leaderboard__item">
              {{#if @showRank}}
                <span
                  class="gamification-block-leaderboard__rank"
                >{{user.position}}</span>
              {{/if}}
              <DUserAvatar @size={{@avatarSize}} @user={{user}} />
              <DUserLink
                class="gamification-block-leaderboard__name"
                @user={{user}}
              >
                {{this.displayName user}}
              </DUserLink>
              <span class="gamification-block-leaderboard__score">
                {{dNumber user.total_score}}
              </span>
            </li>
          {{/each}}
        </ol>
      </:content>
      <:empty>
        <p class="d-block-panel__empty">
          {{i18n "gamification.leaderboard.block.empty"}}
        </p>
      </:empty>
      <:footer>
        {{#if @showFooterLink}}
          <a class="d-block-panel__link" href={{this.leaderboardUrl}}>
            {{this.footerLinkLabel}}
          </a>
        {{/if}}
      </:footer>
    </BlockPanel>
  </template>
}
