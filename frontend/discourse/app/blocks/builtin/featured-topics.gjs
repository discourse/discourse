// @ts-check
import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { URL_PATTERN } from "discourse/lib/blocks";
import {
  fetchTopicList,
  VALID_TOPIC_LIST_FILTERS,
} from "discourse/lib/blocks/-internals/fetch-topic-list";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";

/**
 * Compact card-style topic list intended for sidebar surfaces (e.g.
 * "Hot topics", "Trending now"). Declares its data through the block `data`
 * hook, so the resolved list arrives as `@data` and the block stays a pure
 * renderer. Renders each topic as title + category badge + relative age — no
 * posters, view counts, or excerpts. For full table-style lists with
 * view/activity columns, use the `recent-topics` block instead.
 */
@block("featured-topics", {
  thumbnail: () => import("discourse/blocks/thumbnails/featured-topics"),
  displayName: "Topic highlights",
  icon: "fire",
  category: "Discourse data",
  description: "Compact sidebar list of trending or recent topics.",
  args: {
    title: {
      type: "string",
      default: "Hot topics",
      ui: {
        label: i18n("blocks.builtin.featured_topics.title"),
      },
    },
    filter: {
      type: "string",
      default: "hot",
      enum: VALID_TOPIC_LIST_FILTERS,
      ui: {
        control: "select",
        label: i18n("blocks.builtin.featured_topics.filter"),
      },
    },
    count: {
      type: "number",
      default: 5,
      integer: true,
      min: 1,
      max: 10,
      ui: {
        control: "number",
        label: i18n("blocks.builtin.featured_topics.count"),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n("blocks.builtin.featured_topics.category_id"),
      },
    },
    tag: {
      type: "string",
      ui: {
        control: "tag-select",
        label: i18n("blocks.builtin.featured_topics.tag"),
      },
    },
    linkLabel: {
      type: "string",
      ui: {
        label: i18n("blocks.builtin.featured_topics.link_label"),
      },
    },
    linkHref: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("blocks.builtin.featured_topics.link_href"),
      },
    },
  },
  constraints: {
    allOrNone: ["linkLabel", "linkHref"],
  },
  data: {
    request: (args) => ({
      kind: "topic-list",
      filter: args.filter ?? "hot",
      categoryId: args.categoryId,
      tag: args.tag,
      count: args.count ?? 5,
    }),
    resolve: (descriptor, { owner }) =>
      fetchTopicList({
        store: owner.lookup("service:store"),
        currentUser: owner.lookup("service:current-user"),
        filterType: descriptor.filter,
        categoryId: descriptor.categoryId,
        tag: descriptor.tag,
        count: descriptor.count,
      }),
    skeleton: (args) => ({ variant: "rect", count: args.count ?? 5 }),
  },
})
export default class FeaturedTopics extends Component {
  <template>
    <div class="d-block-featured-topics">
      {{! Chrome: the title renders from args, so it stays visible while the
          list loads. Only the data region below is wrapped in the boundary. }}
      {{#if @title}}
        <h3 class="d-block-featured-topics__title">{{@title}}</h3>
      {{/if}}

      <@Data>
        <:content as |topics|>
          <ul class="d-block-featured-topics__list">
            {{#each topics as |topic|}}
              <li class="d-block-featured-topics__item">
                <a
                  class="d-block-featured-topics__topic-link"
                  href={{topic.lastUnreadUrl}}
                >{{trustHTML topic.fancyTitle}}</a>
                <div class="d-block-featured-topics__meta">
                  {{#if topic.category}}
                    {{dCategoryLink topic.category}}
                  {{/if}}
                  <span class="d-block-featured-topics__age">{{dAgeWithTooltip
                      topic.bumpedAt
                    }}</span>
                </div>
              </li>
            {{/each}}
          </ul>

          {{#if @linkHref}}
            <div class="d-block-featured-topics__footer">
              <a class="d-block-featured-topics__all-link" href={{@linkHref}}>
                {{@linkLabel}}
              </a>
            </div>
          {{/if}}
        </:content>
        <:empty>
          <div class="d-block-featured-topics__empty">
            {{i18n "topics.none.latest"}}
          </div>
        </:empty>
      </@Data>
    </div>
  </template>
}
