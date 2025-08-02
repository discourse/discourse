import Component from "@ember/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import ReviewableTags from "discourse/components/reviewable-tags";
import TopicStatus from "discourse/components/topic-status";
import categoryBadge from "discourse/helpers/category-badge";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import { i18n } from "discourse-i18n";

export default class ReviewableTopicLink extends Component {
  <template>
    <div class="post-topic">
      {{#if this.reviewable.topic}}
        <TopicStatus
          @topic={{this.reviewable.topic}}
          @showPrivateMessageIcon={{true}}
        />
        <a
          href={{this.reviewable.target_url}}
          class="title-text"
        >{{highlightWatchedWords
            this.reviewable.topic.fancyTitle
            this.reviewable
          }}</a>
        {{categoryBadge this.reviewable.category}}
        <ReviewableTags
          @topic={{this.reviewable.topic}}
          @tags={{this.reviewable.topic_tags}}
        />
      {{else if (has-block)}}
        {{yield}}
      {{else}}
        <span class="title-text">
          {{i18n "review.topics.deleted"}}
          <LinkTo
            @route="topic"
            @models={{array "-" this.reviewable.removed_topic_id}}
          >{{i18n "review.topics.original"}}</LinkTo>
        </span>
      {{/if}}
    </div>
  </template>
}
