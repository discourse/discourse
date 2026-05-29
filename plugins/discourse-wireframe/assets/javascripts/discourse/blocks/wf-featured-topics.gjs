// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";
import { URL_PATTERN } from "../lib/arg-patterns";
import {
  fetchTopicList,
  VALID_TOPIC_LIST_FILTERS,
} from "../lib/fetch-topic-list";

/**
 * Compact card-style topic list intended for sidebar surfaces (e.g.
 * "Hot topics", "Trending now"). Renders each topic as title + category
 * badge + relative age — no posters, view counts, or excerpts. For
 * full table-style lists with view/activity columns, use
 * `wf:recent-topics` instead.
 */
@block("wf:featured-topics", {
  displayName: "Topic highlights",
  icon: "fire",
  category: "Discourse data",
  description: "Compact sidebar list of trending or recent topics.",
  args: {
    title: {
      type: "string",
      default: "Hot topics",
      ui: {
        label: i18n("wireframe.inspector.featured_topics.title"),
      },
    },
    filter: {
      type: "string",
      default: "hot",
      enum: VALID_TOPIC_LIST_FILTERS,
      ui: {
        control: "select",
        label: i18n("wireframe.inspector.featured_topics.filter"),
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
        label: i18n("wireframe.inspector.featured_topics.count"),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n("wireframe.inspector.featured_topics.category_id"),
      },
    },
    tag: {
      type: "string",
      ui: {
        control: "tag-select",
        label: i18n("wireframe.inspector.featured_topics.tag"),
      },
    },
    linkLabel: {
      type: "string",
      ui: {
        label: i18n("wireframe.inspector.featured_topics.link_label"),
      },
    },
    linkHref: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("wireframe.inspector.featured_topics.link_href"),
      },
    },
  },
  constraints: {
    allOrNone: ["linkLabel", "linkHref"],
  },
})
export default class WFFeaturedTopics extends Component {
  @service store;
  @service currentUser;

  /**
   * Fetches the topic list to render, delegated to the shared helper.
   * Bound via `@bind` so it can be handed to `DAsyncContent` as a
   * stable function reference (Glimmer would otherwise re-trigger the
   * fetch on every render).
   *
   * @returns {ReturnType<typeof fetchTopicList>}
   */
  @bind
  async fetchTopics() {
    return fetchTopicList({
      store: this.store,
      currentUser: this.currentUser,
      filterType: this.args.filter ?? "hot",
      categoryId: this.args.categoryId,
      tag: this.args.tag,
      count: this.args.count ?? 5,
    });
  }

  <template>
    <div class="wf-featured-topics">
      {{#if @title}}
        <h3 class="wf-featured-topics__title">{{@title}}</h3>
      {{/if}}

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="wf-featured-topics__loading">
            <div class="spinner"></div>
          </div>
        </:loading>

        <:empty>
          <div class="wf-featured-topics__empty">
            {{i18n "topics.none.latest"}}
          </div>
        </:empty>

        <:content as |topics|>
          <ul class="wf-featured-topics__list">
            {{#each topics as |topic|}}
              <li class="wf-featured-topics__item">
                <a
                  class="wf-featured-topics__topic-link"
                  href={{topic.lastUnreadUrl}}
                >{{trustHTML topic.fancyTitle}}</a>
                <div class="wf-featured-topics__meta">
                  {{#if topic.category}}
                    {{dCategoryLink topic.category}}
                  {{/if}}
                  <span class="wf-featured-topics__age">{{dAgeWithTooltip
                      topic.bumpedAt
                    }}</span>
                </div>
              </li>
            {{/each}}
          </ul>

          {{#if @linkHref}}
            <div class="wf-featured-topics__footer">
              <a class="wf-featured-topics__all-link" href={{@linkHref}}>
                {{@linkLabel}}
              </a>
            </div>
          {{/if}}
        </:content>
      </DAsyncContent>
    </div>
  </template>
}
