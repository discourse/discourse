import Component from "@ember/component";
import TopicStatus from "discourse/components/topic-status";
import htmlSafe from "discourse/helpers/html-safe";
import categoryBadge from "discourse/helpers/category-badge";
import ReviewableTags from "discourse/components/reviewable-tags";
import i18n from "discourse/helpers/i18n";
import { LinkTo } from "@ember/routing";
import { array } from "@ember/helper";

export default class ReviewableTopicLink extends Component {<template><div class="post-topic">
  {{#if this.reviewable.topic}}
    <TopicStatus @topic={{this.reviewable.topic}} @showPrivateMessageIcon={{true}} />
    <a href={{this.reviewable.target_url}} class="title-text">{{htmlSafe this.reviewable.topic.fancyTitle}}</a>
    {{categoryBadge this.reviewable.category}}
    <ReviewableTags @tags={{this.reviewable.topic_tags}} @tagName />
  {{else if (has-block)}}
    {{yield}}
  {{else}}
    <span class="title-text">
      {{i18n "review.topics.deleted"}}
      <LinkTo @route="topic" @models={{array "-" this.reviewable.removed_topic_id}}>{{i18n "review.topics.original"}}</LinkTo>
    </span>
  {{/if}}
</div></template>}
