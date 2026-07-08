import { trustHTML } from "@ember/template";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";

const FeaturedTopic = <template>
  <div data-topic-id={{@topic.id}} class="featured-topic --glimmer">
    <TopicStatus @topic={{@topic}} @context="topic-list" />

    <a href={{@topic.lastUnreadUrl}} class="title">{{trustHTML
        @topic.fancyTitle
      }}</a>

    <TopicPostBadges
      @unreadPosts={{@topic.unread_posts}}
      @unseen={{@topic.unseen}}
      @url={{@topic.lastUnreadUrl}}
    />

    <a href={{@topic.lastPostUrl}} class="last-posted-at">{{dAgeWithTooltip
        @topic.last_posted_at
      }}</a>
  </div>
</template>;

export default FeaturedTopic;
