import Component from "@ember/component";
import { array } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import ReviewableTags from "discourse/components/reviewable-tags";
import TopicStatus from "discourse/components/topic-status";
import categoryBadge from "discourse/helpers/category-badge";
import htmlSafe from "discourse/helpers/html-safe";
import iN from "discourse/helpers/i18n";

export default class ReviewableTopicLink extends Component {
  <template>
    <div class="post-topic">
      {{#if this.reviewable.topic}}
        <TopicStatus
          @topic={{this.reviewable.topic}}
          @showPrivateMessageIcon={{true}}
        />
        <a href={{this.reviewable.target_url}} class="title-text">{{htmlSafe
            this.reviewable.topic.fancyTitle
          }}</a>
        {{categoryBadge this.reviewable.category}}
        <ReviewableTags @tags={{this.reviewable.topic_tags}} @tagName />
      {{else if (has-block)}}
        {{yield}}
      {{else}}
        <span class="title-text">
          {{iN "review.topics.deleted"}}
          <LinkTo
            @route="topic"
            @models={{array "-" this.reviewable.removed_topic_id}}
          >{{iN "review.topics.original"}}</LinkTo>
        </span>
      {{/if}}
    </div>
  </template>
}
