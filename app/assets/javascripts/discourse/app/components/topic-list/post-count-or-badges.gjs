import { and } from "truth-helpers";
import PostsCountColumn from "discourse/components/topic-list/posts-count-column";
import TopicPostBadges from "discourse/components/topic-post-badges";

const PostCountOrBadges = <template>
  {{#if (and @postBadgesEnabled @topic.unread_posts)}}
    <TopicPostBadges
      @unreadPosts={{@topic.unread_posts}}
      @unseen={{@topic.unseen}}
      @url={{@topic.lastUnreadUrl}}
    />
  {{else}}
    <PostsCountColumn @topic={{@topic}} @tagName="div" />
  {{/if}}
</template>;

export default PostCountOrBadges;
