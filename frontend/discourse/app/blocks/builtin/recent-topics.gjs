// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import BasicTopicList from "discourse/components/basic-topic-list";
import { URL_PATTERN } from "discourse/lib/blocks";
import {
  fetchTopicList,
  VALID_TOPIC_LIST_FILTERS,
} from "discourse/lib/blocks/-internals/fetch-topic-list";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Real topic-list block. Fetches via `store.findFiltered("topicList", ...)`
 * with optional category, tag, and solved filters. Renders the result
 * through core's `BasicTopicList` inside an `AsyncContent` for clean
 * loading / empty states. The `filter` enum covers latest, top, new,
 * unread, hot, etc., so a single block covers both the "recent" and
 * "hot topics" use cases.
 */
@block("recent-topics", {
  displayName: "Topic list",
  icon: "list",
  category: "Discourse data",
  description: "List of topics with category / tag / solved filters.",
  args: {
    title: {
      type: "string",
      default: "",
      ui: {
        label: i18n("blocks.builtin.recent_topics.title"),
      },
    },
    count: {
      type: "number",
      default: 5,
      integer: true,
      min: 1,
      max: 20,
      ui: {
        control: "number",
        label: i18n("blocks.builtin.recent_topics.count"),
      },
    },
    filter: {
      type: "string",
      default: "latest",
      enum: VALID_TOPIC_LIST_FILTERS,
      ui: {
        control: "select",
        label: i18n("blocks.builtin.recent_topics.filter"),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n("blocks.builtin.recent_topics.category_id"),
      },
    },
    tag: {
      type: "string",
      ui: {
        control: "tag-select",
        label: i18n("blocks.builtin.recent_topics.tag"),
      },
    },
    solved: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.recent_topics.solved"),
      },
    },
    linkLabel: {
      type: "string",
      ui: {
        label: i18n("blocks.builtin.recent_topics.link_label"),
      },
    },
    linkHref: {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        label: i18n("blocks.builtin.recent_topics.link_href"),
      },
    },
  },
  constraints: {
    allOrNone: ["linkLabel", "linkHref"],
  },
})
export default class RecentTopics extends Component {
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
      filterType: this.args.filter ?? "latest",
      categoryId: this.args.categoryId,
      tag: this.args.tag,
      solved: this.args.solved,
      count: this.args.count ?? 5,
    });
  }

  <template>
    <div class="d-block-recent-topics">
      {{#if @title}}
        <div class="d-block-recent-topics__header">
          <h2 class="d-block-recent-topics__title">{{@title}}</h2>
          {{#if @linkHref}}
            <DButton
              class="btn btn-primary d-block-recent-topics__link"
              @href={{@linkHref}}
              @translatedLabel={{@linkLabel}}
            />
          {{/if}}
        </div>
      {{/if}}

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="d-block-recent-topics__loading">
            <div class="spinner"></div>
          </div>
        </:loading>

        <:empty>
          <div class="d-block-recent-topics__empty">
            {{i18n "topics.none.latest"}}
          </div>
        </:empty>

        <:content as |topics|>
          <div class="d-block-recent-topics__list">
            <BasicTopicList @topics={{topics}} @showPosters="true" />

            {{#if @linkHref}}
              <div class="d-block-recent-topics__footer">
                <a class="d-block-recent-topics__all-link" href={{@linkHref}}>
                  {{@linkLabel}}
                </a>
              </div>
            {{/if}}
          </div>
        </:content>
      </DAsyncContent>
    </div>
  </template>
}
