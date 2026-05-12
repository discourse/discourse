import dIcon from "discourse/ui-kit/helpers/d-icon";

const TopicLikesColumn = <template>
  {{#if @topic.like_count}}
    <span class="topic-likes">{{dIcon "heart"}}{{@topic.like_count}}</span>
  {{/if}}
</template>;

export default TopicLikesColumn;
