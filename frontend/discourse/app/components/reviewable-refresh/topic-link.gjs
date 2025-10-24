import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import ReviewableTags from "discourse/components/reviewable-tags";
import TopicStatus from "discourse/components/topic-status";
import categoryBadge from "discourse/helpers/category-badge";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";

/**
 * Displays topic information for reviewable items.
 * Shows the topic title, status, category badge, and tags if the topic exists.
 * For deleted topics, displays a link to the original topic. Supports block content as fallback.
 *
 * @component ReviewableTopicLink
 *
 * @example
 * ```gjs
 * <ReviewableTopicLink @reviewable={{this.reviewable}} />
 *
 * <!-- With block content for custom fallback -->
 * <ReviewableTopicLink @reviewable={{this.reviewable}}>
 *   <span>Custom content when topic is missing</span>
 * </ReviewableTopicLink>
 * ```
 *
 * @param {Reviewable} reviewable - The reviewable object containing topic information
 */
<template>
  <div class="reviewable-topic-link">
    {{#if @reviewable.topic}}
      <div class="reviewable-topic-link__title-wrapper">
        <div class="reviewable-topic-link__title-status">
          <TopicStatus
            @topic={{@reviewable.topic}}
            @showPrivateMessageIcon={{true}}
          />
        </div>

        <div class="reviewable-topic-link__title-link">
          <a
            href={{@reviewable.target_url}}
            class="title-text"
          >{{highlightWatchedWords
              @reviewable.topic.fancyTitle
              @reviewable
            }}</a>
        </div>
      </div>

      <div class="reviewable-topic-link__details">
        <div class="reviewable-topic-link__details-category-badge">
          {{categoryBadge @reviewable.category}}
        </div>

        <div class="reviewable-topic-link__details-tags">
          <ReviewableTags @tags={{@reviewable.topic_tags}} @tagName="" />
        </div>
      </div>
    {{else if (has-block)}}
      {{yield}}
    {{else}}
      <span class="title-text">
        {{i18n "review.topics.deleted"}}
        <LinkTo
          @route="topic"
          @models={{array "-" @reviewable.removed_topic_id}}
        >{{i18n "review.topics.original"}}</LinkTo>
      </span>
    {{/if}}
  </div>
</template>
