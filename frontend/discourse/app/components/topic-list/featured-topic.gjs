import { trustHTML } from "@ember/template";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";

const FeaturedTopic = <template>
  <div class="featured-topic --glimmer" data-topic-id={{@topic.id}}>
    <TopicStatus @context="topic-list" @topic={{@topic}} />

    <a class="title" href={{@topic.lastUnreadUrl}}>{{trustHTML
        @topic.fancyTitle
      }}</a>

    <TopicPostBadges
      @unreadPosts={{@topic.unread_posts}}
      @unseen={{@topic.unseen}}
      @url={{@topic.lastUnreadUrl}}
    />

    <a class="last-posted-at" href={{@topic.lastPostUrl}}>{{dAgeWithTooltip
        @topic.last_posted_at
      }}</a>
  </div>
</template>;

export default FeaturedTopic;
