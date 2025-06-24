import { gt } from "truth-helpers";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";

const TopicRepliesColumn = <template>
  {{#if (gt @topic.replyCount 1)}}
    <span class="topic-replies">{{icon "reply"}}{{number
        @topic.posts_count
      }}</span>
  {{/if}}
</template>;

export default TopicRepliesColumn;
