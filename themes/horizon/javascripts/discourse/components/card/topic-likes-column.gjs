import { themePrefix } from "virtual:theme";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const TopicLikesColumn = <template>
  {{#if @topic.like_count}}
    <span
      class="topic-likes"
      aria-label={{i18n (themePrefix "like_count") count=@topic.like_count}}
    >{{dIcon "heart"}}{{@topic.like_count}}</span>
  {{/if}}
</template>;

export default TopicLikesColumn;
