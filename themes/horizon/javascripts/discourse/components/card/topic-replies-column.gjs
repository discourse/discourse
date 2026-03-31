import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";

const TopicRepliesColumn = <template>
  {{#if @topic.replyCount}}
    <span class="topic-replies">{{icon "reply"}}{{number
        @topic.replyCount
      }}</span>
  {{/if}}
</template>;

export default TopicRepliesColumn;
