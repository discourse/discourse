import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";

const TopicRepliesColumn = <template>
  {{#if @topic.replyCount}}
    <span class="topic-replies">{{dIcon "reply"}}{{dNumber
        @topic.replyCount
      }}</span>
  {{/if}}
</template>;

export default TopicRepliesColumn;
