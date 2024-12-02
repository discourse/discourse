import { and } from "truth-helpers";
import ItemRepliesCell from "discourse/components/topic-list/item/replies-cell";
import TopicPostBadges from "discourse/components/topic-post-badges";

const PostCountOrBadges = <template>
  {{#if (and @postBadgesEnabled @topic.unread_posts)}}
    <TopicPostBadges
      @unreadPosts={{@topic.unread_posts}}
      @unseen={{@topic.unseen}}
      @url={{@topic.lastUnreadUrl}}
    />
  {{else}}
    <ItemRepliesCell @topic={{@topic}} @tagName="div" />
  {{/if}}
</template>;

export default PostCountOrBadges;
