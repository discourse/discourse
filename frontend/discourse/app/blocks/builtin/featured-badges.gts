import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import type { BlockDataComponent } from "discourse/blocks/types";
import {
  type BadgeGrant,
  fetchBadgeGrants,
} from "discourse/lib/blocks/-internals/fetch-badge-grants";
import DBadgeButton from "discourse/ui-kit/d-badge-button";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import { i18n } from "discourse-i18n";

interface FeaturedBadgesSignature {
  Args: {
    Named: {
      title?: string;
      badges?: string;
      maxDays?: number;
      count?: number;
      // Injected by the framework: the data-region boundary, already curried
      // with this block's resolved grants (see `block-layout-wrapper`).
      Data: BlockDataComponent<BadgeGrant[]>;
    };
  };
}

/**
 * A feed of the most recent recipients of a curated set of badges. The
 * `badges` arg is a pipe-separated string of badge IDs, so the same value can
 * be pasted across sites. Each row shows the recipient, the badge they earned,
 * and how long ago it was granted, newest first.
 *
 * Declares its data through the block `data` hook, so the resolved grants
 * arrive as `@data` and the block stays a pure renderer.
 */
@block("featured-badges", {
  thumbnail: () => import("discourse/blocks/thumbnails/featured-badges"),
  displayName: "Recently awarded badges",
  icon: "certificate",
  category: "Discourse data",
  description: "A feed of the most recent recipients of selected badges.",
  args: {
    title: {
      type: "string",
      default: "Recently awarded badges",
      ui: { label: i18n("blocks.builtin.featured_badges.title") },
    },
    badges: {
      type: "string",
      default: "",
      ui: {
        label: i18n("blocks.builtin.featured_badges.badges"),
        helpText: i18n("blocks.builtin.featured_badges.badges_help"),
      },
    },
    maxDays: {
      type: "number",
      default: 15,
      integer: true,
      min: 0,
      ui: {
        control: "number",
        label: i18n("blocks.builtin.featured_badges.max_days"),
      },
    },
    count: {
      type: "number",
      default: 10,
      integer: true,
      min: 1,
      max: 50,
      ui: {
        control: "number",
        label: i18n("blocks.builtin.featured_badges.count"),
      },
    },
  },
  data: {
    request: (args: { badges?: string; maxDays?: number; count?: number }) => ({
      kind: "badge-grants",
      badgeIds: args.badges ?? "",
      maxDays: args.maxDays ?? 0,
      count: args.count ?? 10,
    }),
    resolve: (descriptor: {
      badgeIds: string;
      maxDays: number;
      count: number;
    }) =>
      fetchBadgeGrants({
        badgeIds: descriptor.badgeIds,
        maxDays: descriptor.maxDays,
        count: descriptor.count,
      }),
    skeleton: (args: { count?: number }) => ({
      variant: "rect",
      count: args.count ?? 10,
    }),
  },
})
export default class FeaturedBadges extends Component<FeaturedBadgesSignature> {
  <template>
    <div class="d-block-featured-badges">
      {{#if @title}}
        <h3 class="d-block-featured-badges__title">{{@title}}</h3>
      {{/if}}

      <@Data>
        <:content as |grants|>
          <ul class="d-block-featured-badges__list">
            {{#each grants key="id" as |grant|}}
              <li class="d-block-featured-badges__item">
                <DUserAvatar @user={{grant.user}} @size="medium" />
                <div class="d-block-featured-badges__details">
                  <DUserLink
                    @user={{grant.user}}
                  >{{grant.user.username}}</DUserLink>
                  <span class="d-block-featured-badges__badge">
                    <DBadgeButton @badge={{grant.badge}} />
                  </span>
                </div>
                <span class="d-block-featured-badges__age">
                  {{dAgeWithTooltip grant.grantedAt}}
                </span>
              </li>
            {{/each}}
          </ul>
        </:content>
        <:empty>
          <div class="d-block-featured-badges__empty">
            {{i18n "blocks.builtin.featured_badges.empty"}}
          </div>
        </:empty>
      </@Data>
    </div>
  </template>
}
