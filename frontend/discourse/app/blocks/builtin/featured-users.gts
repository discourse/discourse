import Component from "@glimmer/component";
import type Owner from "@ember/owner";
import { block, defineBlockDataSource } from "discourse/blocks";
import BlockFrame, { frameArgs } from "discourse/blocks/block-frame";
import type { BlockDataComponent } from "discourse/blocks/types";
import {
  fetchUsers,
  VALID_USER_ORDERS,
  VALID_USER_PERIODS,
} from "discourse/lib/blocks/-internals/fetch-users";
import type Store from "discourse/services/store";
import { and } from "discourse/truth-helpers";
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
import DUserLink from "discourse/ui-kit/d-user-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

const featuredUsersDataSource = defineBlockDataSource({
  resolve: (
    descriptor: { period: string; order: string; count: number },
    { owner }: { owner: Owner }
  ) =>
    fetchUsers({
      store: owner.lookup("service:store") as Store,
      period: descriptor.period,
      order: descriptor.order,
      count: descriptor.count,
    }),
});

/**
 * A single directory item yielded by the data boundary. Each carries the
 * ranked user (plus the directory metric, unused by the renderer); the user
 * is a live Discourse model, loosely typed here.
 */
interface FeaturedUser {
  user: { username: string; [key: string]: unknown };
  /** Directory metrics, keyed by the order they rank by. */
  [metric: string]: unknown;
}

interface FeaturedUsersSignature {
  Args: {
    title?: string;
    count?: number;
    period?: string;
    frameStyle?: string;
    icon?: string;
    linkLabel?: string;
    linkHref?: string;
    order?: string;
    /**
     * Injected by the framework: the data-region boundary, already curried
     * with this block's resolved directory items.
     */
    Data: BlockDataComponent<FeaturedUser[]>;
  };
}

/**
 * A list of top contributors for a period, ranked by a directory metric.
 * Declares its data through the block `data` hook, so the resolved directory
 * items arrive as `@data` and the block stays a pure renderer. Each item's
 * `.user` drives the avatar and link.
 */
@block("featured-users", {
  thumbnail: () => import("discourse/blocks/thumbnails/featured-users"),
  displayName: "Top contributors",
  icon: "users",
  category: "community",
  description: "A list of top contributing users for a period.",
  args: {
    title: {
      type: "string",
      default: "Top contributors",
      ui: { label: i18n("blocks.builtin.featured_users.title") },
    },
    count: {
      type: "number",
      default: 5,
      integer: true,
      min: 1,
      max: 20,
      ui: {
        control: "number",
        label: i18n("blocks.builtin.featured_users.count"),
      },
    },
    period: {
      type: "string",
      default: "weekly",
      enum: VALID_USER_PERIODS,
      ui: {
        control: "select",
        label: i18n("blocks.builtin.featured_users.period"),
      },
    },
    order: {
      type: "string",
      default: "likes_received",
      enum: VALID_USER_ORDERS,
      ui: {
        control: "select",
        label: i18n("blocks.builtin.featured_users.order"),
      },
    },
    ...frameArgs({ defaultIcon: "users", withLink: true }),
  },
  data: {
    source: featuredUsersDataSource,
    request: (args: { period?: string; order?: string; count?: number }) => ({
      kind: "user-list",
      period: args.period ?? "weekly",
      order: args.order ?? "likes_received",
      count: args.count ?? 5,
    }),
    skeleton: (args: { count?: number }) => ({
      variant: "rect",
      count: args.count ?? 5,
    }),
  },
})
export default class FeaturedUsers extends Component<FeaturedUsersSignature> {
  /** The directory value the list is ranked by, for one item. */
  score = (item: FeaturedUser): number => Number(item[this.order] ?? 0);

  scoreLabel = (item: FeaturedUser): string =>
    i18n(`blocks.builtin.featured_users.scores.${this.order}`, {
      count: this.score(item),
    });

  get order(): string {
    const order = this.args.order;
    return order && VALID_USER_ORDERS.includes(order)
      ? order
      : "likes_received";
  }

  <template>
    <BlockFrame
      @frameStyle={{@frameStyle}}
      @icon={{@icon}}
      @linkHref={{@linkHref}}
      @linkLabel={{@linkLabel}}
      @title={{@title}}
      as |frame|
    >
      <div
        class={{dConcatClass
          "d-block-featured-users"
          (unless frame.isPlain "d-block-frame__content")
        }}
      >
        {{#if (and frame.isPlain @title)}}
          <h3 class="d-block-featured-users__title">{{@title}}</h3>
        {{/if}}

        <@Data>
          <:content as |items|>
            <ul class="d-block-featured-users__list d-block-frame__rows">
              {{#each items as |item|}}
                <li class="d-block-featured-users__item d-block-frame__row">
                  <DUserAvatar @size="small" @user={{item.user}} />
                  <span class="d-block-featured-users__username">
                    <DUserLink
                      @user={{item.user}}
                    >{{item.user.username}}</DUserLink>
                  </span>
                  <span
                    class="d-block-featured-users__score"
                    title={{this.scoreLabel item}}
                  >
                    <span aria-hidden="true">{{dNumber
                        (this.score item)
                      }}</span>
                    <span class="sr-only">{{this.scoreLabel item}}</span>
                  </span>
                </li>
              {{/each}}
            </ul>
          </:content>
          <:empty>
            <div class="d-block-featured-users__empty">
              {{i18n "blocks.builtin.featured_users.empty"}}
            </div>
          </:empty>
        </@Data>
      </div>
    </BlockFrame>
  </template>
}
