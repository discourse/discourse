// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import {
  fetchUsers,
  VALID_USER_ORDERS,
  VALID_USER_PERIODS,
} from "discourse/lib/blocks/-internals/fetch-users";
/** @type {import("discourse/ui-kit/d-user-avatar.gjs")} */
import DUserAvatar from "discourse/ui-kit/d-user-avatar";
/** @type {import("discourse/ui-kit/d-user-link.gjs")} */
import DUserLink from "discourse/ui-kit/d-user-link";
import { i18n } from "discourse-i18n";

/**
 * A list of top contributors for a period, ranked by a directory metric.
 * Declares its data through the block `data` hook, so the resolved directory
 * items arrive as `@data` and the block stays a pure renderer. Each item's
 * `.user` drives the avatar and link.
 */
@block("featured-users", {
  thumbnail:
    /** @type {() => Promise<typeof import("discourse/blocks/thumbnails/featured-users.gjs")>} */ (
      () => import("discourse/blocks/thumbnails/featured-users")
    ),
  displayName: "Top contributors",
  icon: "users",
  category: "Discourse data",
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
  },
  data: {
    request: (args) => ({
      kind: "user-list",
      period: args.period ?? "weekly",
      order: args.order ?? "likes_received",
      count: args.count ?? 5,
    }),
    resolve: (descriptor, { owner }) =>
      fetchUsers({
        store: owner.lookup("service:store"),
        period: descriptor.period,
        order: descriptor.order,
        count: descriptor.count,
      }),
    skeleton: (args) => ({ variant: "rect", count: args.count ?? 5 }),
  },
})
export default class FeaturedUsers extends Component {
  <template>
    <div class="d-block-featured-users">
      {{#if @title}}
        <h3 class="d-block-featured-users__title">{{@title}}</h3>
      {{/if}}

      <@Data>
        <:content as |items|>
          <ul class="d-block-featured-users__list">
            {{#each items as |item|}}
              <li class="d-block-featured-users__item">
                <DUserAvatar @user={{item.user}} @size="medium" />
                <DUserLink
                  @user={{item.user}}
                >{{item.user.username}}</DUserLink>
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
  </template>
}
