import { and } from "truth-helpers";
import GlimmerPostsCountColumn from "discourse/components/glimmer-posts-count-column";
import TopicPostBadges from "discourse/components/topic-post-badges";

const GlimmerPostCountOrBadges = <template>
  {{#if (and @postBadgesEnabled @topic.unread_posts)}}
    <TopicPostBadges
      @unreadPosts={{@topic.unread_posts}}
      @unseen={{@topic.unseen}}
      @url={{@topic.lastUnreadUrl}}
    />
  {{else}}
    <GlimmerPostsCountColumn @topic={{@topic}} @tagName="div" />
  {{/if}}
</template>;

export default GlimmerPostCountOrBadges;
