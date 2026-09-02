/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import { tagName } from "@ember-decorators/component";
import ReviewableTags from "discourse/components/reviewable-tags";
import TopicStatus from "discourse/components/topic-status";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { i18n } from "discourse-i18n";

@tagName("")
export default class ReviewableTopicLink extends Component {
  <template>
    {{#if this.reviewable.topic}}
      <TopicStatus
        @showPrivateMessageIcon={{true}}
        @topic={{this.reviewable.topic}}
      />
      <a
        class="title-text"
        href={{this.reviewable.target_url}}
      >{{highlightWatchedWords
          this.reviewable.topic.fancyTitle
          this.reviewable
        }}</a>
      {{dCategoryBadge this.reviewable.category}}
      <ReviewableTags
        @tags={{this.reviewable.topic_tags}}
        @topic={{this.reviewable.topic}}
      />
    {{else if (has-block)}}
      {{yield}}
    {{else}}
      <span class="title-text">
        {{i18n "review.topics.deleted"}}
        <LinkTo
          @models={{array "-" this.reviewable.removed_topic_id}}
          @route="topic"
        >{{i18n "review.topics.original"}}</LinkTo>
      </span>
    {{/if}}
  </template>
}
