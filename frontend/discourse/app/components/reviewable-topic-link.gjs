import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import ReviewableTags from "discourse/components/reviewable-tags";
import TopicStatus from "discourse/components/topic-status";
import highlightWatchedWords from "discourse/lib/highlight-watched-words";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import { i18n } from "discourse-i18n";

const ReviewableTopicLink = <template>
  {{#if @reviewable.topic}}
    <TopicStatus
      @showPrivateMessageIcon={{true}}
      @topic={{@reviewable.topic}}
    />
    <a
      class="title-text"
      href={{@reviewable.target_url}}
    >{{highlightWatchedWords @reviewable.topic.fancyTitle @reviewable}}</a>
    {{dCategoryBadge @reviewable.category}}
    <ReviewableTags
      @tags={{@reviewable.topic_tags}}
      @topic={{@reviewable.topic}}
    />
  {{else if (has-block)}}
    {{yield}}
  {{else}}
    <span class="title-text">
      {{i18n "review.topics.deleted"}}
      <LinkTo
        @models={{array "-" @reviewable.removed_topic_id}}
        @route="topic"
      >{{i18n "review.topics.original"}}</LinkTo>
    </span>
  {{/if}}
</template>;

export default ReviewableTopicLink;
