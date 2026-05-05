import ItemRepliesCell from "discourse/components/topic-list/item/replies-cell";
import NewRepliesDot from "discourse/components/topic-list/new-replies-dot";
import TopicPostBadges from "discourse/components/topic-post-badges";
import { and } from "discourse/truth-helpers";

const PostCountOrBadges = <template>
  {{#if @topic.is_nested_view}}
    {{#if @topic.has_new_replies}}
      <NewRepliesDot @topic={{@topic}} />
    {{else}}
      <ItemRepliesCell @topic={{@topic}} @tagName="div" />
    {{/if}}
  {{else if (and @postBadgesEnabled @topic.unread_posts)}}
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
