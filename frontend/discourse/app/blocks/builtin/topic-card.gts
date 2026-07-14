import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import type { BlockDataComponent } from "discourse/blocks/types";
import { fetchTopicCard } from "discourse/lib/blocks/-internals/fetch-topic-card";
import { and, not, or } from "discourse/truth-helpers";
import DSkeleton from "discourse/ui-kit/d-skeleton";
import { i18n } from "discourse-i18n";

/** An editable image arg: a light URL plus an optional dark-scheme variant. */
interface BlockImageArg {
  url?: string;
  dark?: { url?: string };
}

/** The card-facing projection of a topic yielded by the data boundary. */
interface TopicCardData {
  url?: string;
  title?: string;
  fancyTitle?: string;
  categoryBadge?: string | null;
  imageUrl?: string | null;
  excerpt?: string | null;
}

interface TopicCardSignature {
  Args: {
    topicId?: number;
    image?: BlockImageArg;
    showExcerpt?: boolean;
    hideWhenUnavailable?: boolean;
    /**
     * Injected by the framework: the data-region boundary, already curried
     * with this block's resolved topic.
     */
    Data: BlockDataComponent<TopicCardData>;
  };
}

/**
 * A card for a single hand-picked topic, resolved by id. Renders the topic's
 * title, category badge, and either a background image (its own, or a custom
 * override) or a short excerpt. Drop several into a `layout` in grid mode and
 * size each via the grid placement (e.g. span the hero card across all
 * columns) to build a curated topic showcase.
 *
 * Declares its data through the block `data` hook, so the resolved topic
 * arrives as `@data` and the block stays a pure renderer.
 */
@block("topic-card", {
  thumbnail: () => import("discourse/blocks/thumbnails/topic-card"),
  displayName: "Topic card",
  icon: "book",
  category: "Discourse data",
  description: "A card for a single hand-picked topic, resolved by its id.",
  args: {
    topicId: {
      type: "number",
      integer: true,
      min: 1,
      ui: {
        control: "topic-select",
        label: i18n("blocks.builtin.topic_card.topic_id"),
        helpText: i18n("blocks.builtin.topic_card.topic_id_help"),
        emptyPrompt: i18n("blocks.builtin.topic_card.empty_prompt"),
      },
    },
    image: {
      type: "image",
      allowDark: true,
      allowResize: false,
      aspectRatio: "auto",
      defaultFit: "cover",
      ui: {
        label: i18n("blocks.builtin.topic_card.image"),
        helpText: i18n("blocks.builtin.topic_card.image_help"),
      },
    },
    showExcerpt: {
      type: "boolean",
      default: true,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.topic_card.show_excerpt"),
        helpText: i18n("blocks.builtin.topic_card.show_excerpt_help"),
      },
    },
    hideWhenUnavailable: {
      type: "boolean",
      default: false,
      ui: {
        control: "toggle",
        label: i18n("blocks.builtin.topic_card.hide_when_unavailable"),
        helpText: i18n("blocks.builtin.topic_card.hide_when_unavailable_help"),
      },
    },
  },
  data: {
    request: (args: { topicId?: number }) => ({
      kind: "topic-card",
      topicId: args.topicId,
    }),
    resolve: (descriptor: { topicId?: number }) =>
      fetchTopicCard({ topicId: descriptor.topicId }),
  },
})
export default class TopicCard extends Component<TopicCardSignature> {
  <template>
    <div class="d-block-topic-card">
      <@Data>
        <:content as |topic|>
          {{#let (or @image.url topic.imageUrl) as |bgUrl|}}
            {{#if bgUrl}}
              <div
                class="d-block-topic-card__background"
                data-block-arg="image"
                style={{trustHTML (concat "background-image: url(" bgUrl ")")}}
              ></div>
              <div class="d-block-topic-card__overlay"></div>
            {{/if}}

            <div class="d-block-topic-card__details">
              {{#if topic.categoryBadge}}
                <div class="d-block-topic-card__category">
                  {{trustHTML topic.categoryBadge}}
                </div>
              {{/if}}

              <h3 class="d-block-topic-card__title">
                {{trustHTML topic.fancyTitle}}
              </h3>

              {{#if (and @showExcerpt (not bgUrl) topic.excerpt)}}
                <p class="d-block-topic-card__excerpt">{{topic.excerpt}}</p>
              {{/if}}
            </div>

            <a
              class="d-block-stretched-link"
              href={{topic.url}}
              aria-label={{topic.title}}
            ></a>
          {{/let}}
        </:content>
        <:loading>
          <div
            class="d-block-topic-card__details d-block-topic-card__skeleton"
            aria-hidden="true"
          >
            <DSkeleton
              class="d-block-topic-card__skeleton-category"
              @variant="text"
              @width="8ch"
            />
            <h3 class="d-block-topic-card__title">
              <DSkeleton @variant="text" @width="22ch" />
            </h3>
            {{#if (and @showExcerpt (not @image.url))}}
              <DSkeleton @variant="text" @count={{3}} @lastLineWidth="18ch" />
            {{/if}}
          </div>
        </:loading>
        <:empty>
          {{! Intentionally bare — any prompt to configure this block is painted
              by external tooling, never on the render path. }}
          <div class="d-block-topic-card__empty"></div>
        </:empty>
        <:error>
          {{#unless @hideWhenUnavailable}}
            <div class="d-block-topic-card__unavailable">
              {{i18n "blocks.builtin.topic_card.unavailable"}}
            </div>
          {{/unless}}
        </:error>
      </@Data>
    </div>
  </template>
}
