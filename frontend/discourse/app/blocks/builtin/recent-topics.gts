import Component from "@glimmer/component";
import type Owner from "@ember/owner";
import { block } from "discourse/blocks";
import type { BlockDataComponent } from "discourse/blocks/types";
import BasicTopicList from "discourse/components/basic-topic-list";
import { URL_PATTERN } from "discourse/lib/blocks";
import {
  fetchTopicList,
  VALID_TOPIC_LIST_FILTERS,
} from "discourse/lib/blocks/-internals/fetch-topic-list";
import type User from "discourse/models/user";
import type Store from "discourse/services/store";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

interface RecentTopicsSignature {
  Args: {
    title?: string;
    count?: number;
    filter?: string;
    categoryId?: number;
    tag?: string;
    solved?: boolean;
    linkLabel?: string;
    linkHref?: string;
    /**
     * Injected by the framework: the data-region boundary, already curried
     * with this block's resolved topic list.
     */
    Data: BlockDataComponent<object[]>;
  };
}

/**
 * Real topic-list block. Declares its data through the block `data` hook, so
 * the resolved topic list arrives as `@data` and the block stays a pure
 * renderer — no fetch, services, or loading markup of its own. The framework
 * owns the loading boundary and serves preloaded data when available. Renders
 * through core's `BasicTopicList`. The `filter` enum covers latest, top, new,
 * unread, hot, etc., so one block covers both the "recent" and "hot topics"
 * cases.
 */
@block("recent-topics", {
  thumbnail: () => import("discourse/blocks/thumbnails/recent-topics"),
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
  data: {
    request: (args: {
      filter?: string;
      categoryId?: number;
      tag?: string;
      solved?: boolean;
      count?: number;
    }) => ({
      kind: "topic-list",
      filter: args.filter ?? "latest",
      categoryId: args.categoryId,
      tag: args.tag,
      solved: args.solved ?? false,
      count: args.count ?? 5,
    }),
    resolve: (
      descriptor: {
        filter: string;
        categoryId?: number;
        tag?: string;
        solved: boolean;
        count: number;
      },
      { owner }: { owner: Owner }
    ) =>
      fetchTopicList({
        store: owner.lookup("service:store") as Store,
        currentUser: owner.lookup("service:current-user") as User | null,
        filterType: descriptor.filter,
        categoryId: descriptor.categoryId,
        tag: descriptor.tag,
        solved: descriptor.solved,
        count: descriptor.count,
      }),
    skeleton: (args: { count?: number }) => ({
      variant: "rect",
      count: args.count ?? 5,
    }),
  },
})
export default class RecentTopics extends Component<RecentTopicsSignature> {
  <template>
    <div class="d-block-recent-topics">
      {{! Chrome: the header (title + link) renders from args, so it stays
          visible while the list loads. Only the list below is in the boundary. }}
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

      <@Data>
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
        <:empty>
          <div class="d-block-recent-topics__empty">
            {{i18n "topics.none.latest"}}
          </div>
        </:empty>
      </@Data>
    </div>
  </template>
}
