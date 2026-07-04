// @ts-check
import Component from "@glimmer/component";
import { block } from "discourse/blocks";
import {
  fetchTags,
  VALID_TAG_SORTS,
} from "discourse/lib/blocks/-internals/fetch-tags";
import dDiscourseTag from "discourse/ui-kit/helpers/d-discourse-tag";
import { i18n } from "discourse-i18n";

/**
 * A list of tags — popular or alphabetical. Declares its data through the
 * block `data` hook, so the resolved tags arrive as `@data` and the block
 * stays a pure renderer.
 */
@block("featured-tags", {
  thumbnail:
    /** @type {() => Promise<typeof import("discourse/blocks/thumbnails/featured-tags.gjs")>} */ (
      () => import("discourse/blocks/thumbnails/featured-tags")
    ),
  displayName: "Featured tags",
  icon: "tag",
  category: "Discourse data",
  description: "A list of popular or alphabetical tags.",
  args: {
    title: {
      type: "string",
      default: "Tags",
      ui: { label: i18n("blocks.builtin.featured_tags.title") },
    },
    count: {
      type: "number",
      default: 10,
      integer: true,
      min: 1,
      max: 30,
      ui: {
        control: "number",
        label: i18n("blocks.builtin.featured_tags.count"),
      },
    },
    sort: {
      type: "string",
      default: "popular",
      enum: VALID_TAG_SORTS,
      ui: {
        control: "select",
        label: i18n("blocks.builtin.featured_tags.sort"),
      },
    },
  },
  data: {
    request: (args) => ({
      kind: "tag-list",
      count: args.count ?? 10,
      sort: args.sort ?? "popular",
    }),
    resolve: (descriptor, { owner }) =>
      fetchTags({
        store: owner.lookup("service:store"),
        count: descriptor.count,
        sort: descriptor.sort,
      }),
    skeleton: (args) => ({ variant: "pill", count: args.count ?? 10 }),
  },
})
export default class FeaturedTags extends Component {
  <template>
    <div class="d-block-featured-tags">
      {{#if @title}}
        <h3 class="d-block-featured-tags__title">{{@title}}</h3>
      {{/if}}

      <@Data>
        <:content as |tags|>
          <div class="d-block-featured-tags__list">
            {{#each tags as |tag|}}
              {{dDiscourseTag tag.name}}
            {{/each}}
          </div>
        </:content>
        <:empty>
          <div class="d-block-featured-tags__empty">
            {{i18n "blocks.builtin.featured_tags.empty"}}
          </div>
        </:empty>
      </@Data>
    </div>
  </template>
}
