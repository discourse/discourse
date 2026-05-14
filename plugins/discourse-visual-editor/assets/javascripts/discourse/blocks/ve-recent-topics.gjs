// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import { block } from "discourse/blocks";
import BasicTopicList from "discourse/components/basic-topic-list";
import { bind } from "discourse/lib/decorators";
import Category from "discourse/models/category";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const VALID_FILTERS = ["latest", "top", "hot", "new", "unread"];
const USER_ONLY_FILTERS = new Set(["new", "unread"]);

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
@block("ve:recent-topics", {
  displayName: "Topic list",
  icon: "list",
  category: "Discourse data",
  description: "List of topics with category / tag / solved filters.",
  args: {
    title: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.recent_topics.title"),
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
        label: i18n("visual_editor.inspector.recent_topics.count"),
      },
    },
    filter: {
      type: "string",
      default: "latest",
      enum: VALID_FILTERS,
      ui: {
        control: "select",
        label: i18n("visual_editor.inspector.recent_topics.filter"),
      },
    },
    categoryId: {
      type: "number",
      ui: {
        control: "category-select",
        label: i18n("visual_editor.inspector.recent_topics.category_id"),
      },
    },
    tag: {
      type: "string",
      ui: {
        control: "tag-select",
        label: i18n("visual_editor.inspector.recent_topics.tag"),
      },
    },
    solved: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("visual_editor.inspector.recent_topics.solved"),
      },
    },
    linkLabel: {
      type: "string",
      default: "",
      ui: {
        label: i18n("visual_editor.inspector.recent_topics.link_label"),
      },
    },
    linkHref: {
      type: "string",
      default: "",
      ui: {
        control: "url",
        label: i18n("visual_editor.inspector.recent_topics.link_href"),
      },
    },
  },
  previewArgs: { count: 5, filter: "latest" },
})
export default class VERecentTopics extends Component {
  @service store;
  @service currentUser;

  /**
   * Builds the topic-list filter path for the requested combination of
   * filter type + category + tag. Mirrors core's URL conventions so
   * `store.findFiltered` resolves the right endpoint.
   *
   * @param {string} filterType
   * @param {number} [categoryId]
   * @param {string} [tag]
   * @returns {string}
   */
  #buildFilterPath(filterType, categoryId, tag) {
    if (categoryId && tag) {
      const category = Category.findById(categoryId);
      if (category) {
        return `tags/c/${Category.slugFor(category)}/${category.id}/${tag}/l/${filterType}`;
      }
    }
    if (categoryId) {
      const category = Category.findById(categoryId);
      if (category) {
        return `c/${Category.slugFor(category)}/${category.id}/l/${filterType}`;
      }
    }
    if (tag) {
      return `tag/${tag}/l/${filterType}`;
    }
    return filterType;
  }

  @bind
  async fetchTopics() {
    const count = this.args.count ?? 5;
    const filterType = this.args.filter ?? "latest";
    const { categoryId, tag, solved } = this.args;

    if (USER_ONLY_FILTERS.has(filterType) && !this.currentUser) {
      return null;
    }

    const filter = this.#buildFilterPath(filterType, categoryId, tag);
    const params = solved ? { solved } : {};

    const topicList = await this.store.findFiltered("topicList", {
      filter,
      params,
    });

    if (!topicList?.topics?.length) {
      return null;
    }
    return topicList.topics.slice(0, count);
  }

  <template>
    <div class="ve-recent-topics">
      {{#if @title}}
        <div class="ve-recent-topics__header">
          <h2 class="ve-recent-topics__title">{{@title}}</h2>
          {{#if @linkHref}}
            <DButton
              class="btn btn-primary ve-recent-topics__link"
              @href={{@linkHref}}
              @translatedLabel={{@linkLabel}}
            />
          {{/if}}
        </div>
      {{/if}}

      <DAsyncContent @asyncData={{this.fetchTopics}}>
        <:loading>
          <div class="ve-recent-topics__loading">
            <div class="spinner"></div>
          </div>
        </:loading>

        <:empty>
          <div class="ve-recent-topics__empty">
            {{i18n "topics.none.latest"}}
          </div>
        </:empty>

        <:content as |topics|>
          <div class="ve-recent-topics__list">
            <BasicTopicList @topics={{topics}} @showPosters="true" />

            {{#if @linkHref}}
              <div class="ve-recent-topics__footer">
                <a class="ve-recent-topics__all-link" href={{@linkHref}}>
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
