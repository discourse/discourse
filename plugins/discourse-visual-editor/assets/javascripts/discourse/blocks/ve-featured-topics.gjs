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
import {
  fetchTopicList,
  VALID_TOPIC_LIST_FILTERS,
} from "../lib/fetch-topic-list";

/**
 * Compact card-style topic list intended for sidebar surfaces (e.g.
 * "Hot topics", "Trending now"). Renders each topic as title + category
 * badge + relative age — no posters, view counts, or excerpts. For
 * full table-style lists with view/activity columns, use
 * `ve:recent-topics` instead.
 */
@block("ve:featured-topics", {
  displayName: "Topic highlights",
  icon: "fire",
  category: "Discourse data",
  description: "Compact sidebar list of trending or recent topics.",
  args: {
    title: {
      type: "string",
      default: "Hot topics",
      ui: {
        label: i18n("visual_editor.inspector.featured_topics.title"),
      },
    },
    filter: {
      type: "string",
      default: "hot",
      enum: VALID_TOPIC_LIST_FILTERS,
      ui: {
        control: "select",
        label: i18n("visual_editor.inspector.featured_topics.filter"),
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
        label: i18n("visual_editor.inspector.featured_topics.count"),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n("visual_editor.inspector.featured_topics.category_id"),
      },
    },
    tag: {
      type: "string",
      ui: {
        control: "tag-select",
        label: i18n("visual_editor.inspector.featured_topics.tag"),
      },
    },
    linkLabel: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.featured_topics.link_label"),
      },
    },
    linkHref: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        label: i18n("visual_editor.inspector.featured_topics.link_href"),
      },
    },
  },
  previewArgs: { title: "Hot topics", filter: "hot", count: 5 },
})
export default class VEFeaturedTopics extends Component {
  @service store;
  @service currentUser;

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
    <div class="ve-featured-topics">
      {{#if @title}}
        <h3 class="ve-featured-topics__title">{{@title}}</h3>
      {{/if}}

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="ve-featured-topics__loading">
            <div class="spinner"></div>
          </div>
        </:loading>

        <:empty>
          <div class="ve-featured-topics__empty">
            {{i18n "topics.none.latest"}}
          </div>
        </:empty>

        <:content as |topics|>
          <ul class="ve-featured-topics__list">
            {{#each topics as |topic|}}
              <li class="ve-featured-topics__item">
                <a
                  class="ve-featured-topics__topic-link"
                  href={{topic.lastUnreadUrl}}
                >{{trustHTML topic.fancyTitle}}</a>
                <div class="ve-featured-topics__meta">
                  {{#if topic.category}}
                    {{dCategoryLink topic.category}}
                  {{/if}}
                  <span class="ve-featured-topics__age">{{dAgeWithTooltip
                      topic.bumpedAt
                    }}</span>
                </div>
              </li>
            {{/each}}
          </ul>

          {{#if @linkHref}}
            <div class="ve-featured-topics__footer">
              <a class="ve-featured-topics__all-link" href={{@linkHref}}>
                {{@linkLabel}}
              </a>
            </div>
          {{/if}}
        </:content>
      </DAsyncContent>
    </div>
  </template>
}
