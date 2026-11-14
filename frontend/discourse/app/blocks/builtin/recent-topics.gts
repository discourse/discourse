import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import BlockFrame, { frameArgs } from "discourse/blocks/block-frame";
import type { BlockDataComponent } from "discourse/blocks/types";
import BasicTopicList from "discourse/components/basic-topic-list";
import { URL_PATTERN } from "discourse/lib/blocks";
import { VALID_TOPIC_LIST_FILTERS } from "discourse/lib/blocks/-internals/fetch-topic-list";
import { topicListDataSource } from "discourse/lib/blocks/-internals/sources/topic-list";
import { and } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dOnResize from "discourse/ui-kit/modifiers/d-on-resize";
import { i18n } from "discourse-i18n";

/** Below this width the table gives way to compact rows. */
const COMPACT_WIDTH = 600;

/** The topic fields the compact rows read; the table takes the full model. */
interface RecentTopic {
  lastUnreadUrl?: string;
  fancyTitle?: string;
  category?: unknown;
  bumpedAt?: unknown;
}

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
    frameStyle?: string;
    icon?: string;
    showPosters?: boolean;
    showReplies?: boolean;
    showViews?: boolean;
    showActivity?: boolean;
    /**
     * Injected by the framework: the data-region boundary, already curried
     * with this block's resolved topic list.
     */
    Data: BlockDataComponent<RecentTopic[]>;
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
  category: "community",
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
    showPosters: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        group: i18n("blocks.builtin.recent_topics.columns"),
        label: i18n("blocks.builtin.recent_topics.show_posters"),
      },
    },
    showReplies: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        group: i18n("blocks.builtin.recent_topics.columns"),
        label: i18n("blocks.builtin.recent_topics.show_replies"),
      },
    },
    showViews: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        group: i18n("blocks.builtin.recent_topics.columns"),
        label: i18n("blocks.builtin.recent_topics.show_views"),
      },
    },
    showActivity: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        group: i18n("blocks.builtin.recent_topics.columns"),
        label: i18n("blocks.builtin.recent_topics.show_activity"),
      },
    },
    ...frameArgs({ defaultIcon: "list" }),
  },
  constraints: {
    allOrNone: ["linkLabel", "linkHref"],
  },
  data: {
    source: topicListDataSource,
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
    skeleton: (args: { count?: number }) => ({
      variant: "rect",
      count: args.count ?? 5,
    }),
  },
})
export default class RecentTopics extends Component<RecentTopicsSignature> {
  @tracked isCompact = false;

  onResize = (entries: ResizeObserverEntry[]): void => {
    const width = entries.at(-1)?.contentRect.width;
    if (width) {
      this.isCompact = width < COMPACT_WIDTH;
    }
  };

  get hiddenColumns(): string[] {
    const hidden: string[] = [];
    if (this.args.showReplies === false) {
      hidden.push("replies");
    }
    if (this.args.showViews === false) {
      hidden.push("views");
    }
    if (this.args.showActivity === false) {
      hidden.push("activity");
    }
    return hidden;
  }

  <template>
    <BlockFrame
      @flush={{true}}
      @frameStyle={{@frameStyle}}
      @icon={{@icon}}
      @linkHref={{@linkHref}}
      @linkLabel={{@linkLabel}}
      @title={{@title}}
      as |frame|
    >
      <div
        class={{dConcatClass
          "d-block-recent-topics"
          (if this.isCompact "--compact")
          (unless frame.isPlain "d-block-frame__content")
        }}
        {{dOnResize this.onResize}}
      >
        {{! Chrome: the header (title + link) renders from args, so it stays
          visible while the list loads. Only the list below is in the boundary. }}
        {{#if (and frame.isPlain @title)}}
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
              {{#if this.isCompact}}
                <ul class="d-block-recent-topics__rows d-block-frame__rows">
                  {{#each topics as |topic|}}
                    <li class="d-block-recent-topics__row d-block-frame__row">
                      <a
                        class="d-block-recent-topics__row-title"
                        href={{topic.lastUnreadUrl}}
                      >{{trustHTML topic.fancyTitle}}</a>
                      <div class="d-block-recent-topics__row-meta">
                        {{#if topic.category}}
                          {{dCategoryLink topic.category}}
                        {{/if}}
                        <span
                          class="d-block-recent-topics__row-age"
                        >{{dAgeWithTooltip topic.bumpedAt}}</span>
                      </div>
                    </li>
                  {{/each}}
                </ul>
              {{else}}
                <BasicTopicList
                  @hiddenColumns={{this.hiddenColumns}}
                  @showPosters={{@showPosters}}
                  @topics={{topics}}
                />
              {{/if}}

              {{#if (and frame.isPlain @linkHref)}}
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
    </BlockFrame>
  </template>
}
