import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import BlockPanel from "discourse/blocks/block-panel";
import type { BlockDataComponent } from "discourse/blocks/types";
import { URL_PATTERN } from "discourse/lib/blocks";
import {
  topicListUrl,
  VALID_TOPIC_LIST_FILTERS,
  VALID_TOPIC_LIST_ORDERS,
} from "discourse/lib/blocks/-internals/fetch-topic-list";
import { topicListDataSource } from "discourse/lib/blocks/-internals/sources/topic-list";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dCategoryLink from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";

/**
 * A single topic yielded by the data boundary — a live Discourse topic model,
 * projected to the fields the compact card renders.
 */
interface FeaturedTopic {
  lastUnreadUrl?: string;
  fancyTitle?: string;
  category?: unknown;
  bumpedAt?: unknown;
}

interface CategoryOutletArg {
  id: number;
  parentCategory?: CategoryOutletArg | null;
}

interface FeaturedTopicsArgs {
  categoryId?: number;
  currentCategory?: boolean;
  outletArgs?: { category?: CategoryOutletArg | null };
}

/**
 * The category whose topics the block lists. With `currentCategory`, a
 * category page lists its top-level category, so subcategories of one
 * category share a list; elsewhere the picked category applies.
 */
function listCategoryId(args: FeaturedTopicsArgs): number | undefined {
  if (args.currentCategory) {
    const category = args.outletArgs?.category;
    const topLevel = category?.parentCategory ?? category;
    if (topLevel) {
      return topLevel.id;
    }
  }
  return args.categoryId;
}

interface FeaturedTopicsSignature {
  Args: {
    title?: string;
    icon?: string;
    filter?: string;
    order?: string;
    count?: number;
    categoryId?: number;
    currentCategory?: boolean;
    tag?: string;
    linkLabel?: string;
    linkHref?: string;
    outletArgs?: { category?: CategoryOutletArg | null };
    /**
     * Injected by the framework: the data-region boundary, already curried
     * with this block's resolved topic list.
     */
    Data: BlockDataComponent<FeaturedTopic[]>;
  };
}

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
  category: "community",
  description: "Compact sidebar list of trending or recent topics.",
  args: {
    title: {
      type: "string",
      default: "Hot topics",
      ui: {
        label: i18n("blocks.builtin.featured_topics.title"),
      },
    },
    icon: {
      type: "string",
      ui: {
        control: "icon",
        label: i18n("blocks.builtin.featured_topics.icon"),
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
    order: {
      type: "string",
      enum: VALID_TOPIC_LIST_ORDERS,
      ui: {
        control: "select",
        label: i18n("blocks.builtin.featured_topics.order"),
        helpText: i18n("blocks.builtin.featured_topics.order_help"),
        optionLabels: {
          activity: i18n("blocks.builtin.featured_topics.order_activity"),
          created: i18n("blocks.builtin.featured_topics.order_created"),
          likes: i18n("blocks.builtin.featured_topics.order_likes"),
          views: i18n("blocks.builtin.featured_topics.order_views"),
          posts: i18n("blocks.builtin.featured_topics.order_posts"),
        },
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
    currentCategory: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.featured_topics.current_category"),
        helpText: i18n("blocks.builtin.featured_topics.current_category_help"),
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
    source: topicListDataSource,
    request: (
      args: FeaturedTopicsArgs & {
        filter?: string;
        order?: string;
        tag?: string;
        count?: number;
      }
    ) => ({
      kind: "topic-list",
      filter: args.filter ?? "hot",
      order: args.order,
      categoryId: listCategoryId(args),
      tag: args.tag,
      count: args.count ?? 5,
    }),
    skeleton: (args: { count?: number }) => ({
      rows: "topic",
      count: args.count ?? 5,
    }),
  },
})
export default class FeaturedTopics extends Component<FeaturedTopicsSignature> {
  /** The full list the block shows a part of, unless a link is given. */
  get viewAllUrl(): string {
    return topicListUrl({
      filterType: this.args.filter ?? "hot",
      order: this.args.order,
      categoryId: listCategoryId(this.args),
      tag: this.args.tag,
    });
  }

  <template>
    <BlockPanel
      class="d-block-featured-topics"
      @Data={{@Data}}
      @icon={{@icon}}
      @title={{@title}}
    >
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
      </:content>
      <:empty>
        <p class="d-block-panel__empty">{{i18n "topics.none.latest"}}</p>
      </:empty>
      <:footer>
        {{#if @linkHref}}
          <a class="d-block-panel__link" href={{@linkHref}}>{{@linkLabel}}</a>
        {{else}}
          <a class="d-block-panel__link" href={{this.viewAllUrl}}>
            {{i18n "blocks.builtin.featured_topics.view_all"}}
          </a>
        {{/if}}
      </:footer>
    </BlockPanel>
  </template>
}
