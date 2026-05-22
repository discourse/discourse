// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import BasicTopicList from "discourse/components/basic-topic-list";
import { bind } from "discourse/lib/decorators";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  fetchTopicList,
  VALID_TOPIC_LIST_FILTERS,
} from "../lib/fetch-topic-list";

/**
 * Real topic-list block. Fetches via `store.findFiltered("topicList", ...)`
 * with optional category, tag, and solved filters. Renders the result
 * through core's `BasicTopicList` inside an `AsyncContent` for clean
 * loading / empty states.
 *
 * Ported from `discourse/meta-branded-theme`'s `block-featured-list.gjs`
 * (the self-contained `main`-branch version, not the PR variant that
 * reads from `outletArgs.model`). The `filter` enum also covers the
 * `"hot"` use case from the theme's hot-topics block, so a single
 * block covers both surfaces.
 */
@block("wf:recent-topics", {
  displayName: "Topic list",
  icon: "list",
  category: "Discourse data",
  description: "List of topics with category / tag / solved filters.",
  args: {
    title: {
      type: "string",
      default: "",
      ui: {
        label: i18n("wireframe.inspector.recent_topics.title"),
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
        label: i18n("wireframe.inspector.recent_topics.count"),
      },
    },
    filter: {
      type: "string",
      default: "latest",
      enum: VALID_TOPIC_LIST_FILTERS,
      ui: {
        control: "select",
        label: i18n("wireframe.inspector.recent_topics.filter"),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n("wireframe.inspector.recent_topics.category_id"),
      },
    },
    tag: {
      type: "string",
      ui: {
        control: "tag-select",
        label: i18n("wireframe.inspector.recent_topics.tag"),
      },
    },
    solved: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("wireframe.inspector.recent_topics.solved"),
      },
    },
    linkLabel: {
      type: "string",
      default: "",
      ui: {
        label: i18n("wireframe.inspector.recent_topics.link_label"),
      },
    },
    linkHref: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        label: i18n("wireframe.inspector.recent_topics.link_href"),
      },
    },
  },
})
export default class WFRecentTopics extends Component {
  @service store;
  @service currentUser;

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
    <div class="wf-recent-topics">
      {{#if @title}}
        <div class="wf-recent-topics__header">
          <h2 class="wf-recent-topics__title">{{@title}}</h2>
          {{#if @linkHref}}
            <DButton
              class="btn btn-primary wf-recent-topics__link"
              @href={{@linkHref}}
              @translatedLabel={{@linkLabel}}
            />
          {{/if}}
        </div>
      {{/if}}

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="wf-recent-topics__loading">
            <div class="spinner"></div>
          </div>
        </:loading>

        <:empty>
          <div class="wf-recent-topics__empty">
            {{i18n "topics.none.latest"}}
          </div>
        </:empty>

        <:content as |topics|>
          <div class="wf-recent-topics__list">
            <BasicTopicList @topics={{topics}} @showPosters="true" />

            {{#if @linkHref}}
              <div class="wf-recent-topics__footer">
                <a class="wf-recent-topics__all-link" href={{@linkHref}}>
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
