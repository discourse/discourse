import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dNumber from "discourse/ui-kit/helpers/d-number";
import { i18n } from "discourse-i18n";

const TopicRepliesColumn = <template>
  {{#if @topic.replyCount}}
    <span
      class="topic-replies"
      aria-label={{i18n (themePrefix "reply_count") count=@topic.replyCount}}
    >{{dIcon "reply"}}{{dNumber @topic.replyCount}}</span>
  {{/if}}
</template>;

export default TopicRepliesColumn;
