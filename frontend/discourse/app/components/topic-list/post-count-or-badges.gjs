import ItemRepliesCell from "discourse/components/topic-list/item/replies-cell";
import TopicPostBadges from "discourse/components/topic-post-badges";
import { and } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const PostCountOrBadges = <template>
  {{#if @topic.is_nested_view}}
    {{#if @topic.has_new_replies}}
      {{~! no whitespace ~}}
      <span class="topic-post-badges">&nbsp;<a
          href={{@topic.lastUnreadUrl}}
          title={{i18n "topic.has_new_replies"}}
          aria-label={{i18n "topic.has_new_replies"}}
          class="badge badge-notification new-replies"
        >&nbsp;</a></span>
      {{~! no whitespace ~}}
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
