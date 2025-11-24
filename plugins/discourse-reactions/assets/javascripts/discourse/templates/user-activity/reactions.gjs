import PostList from "discourse/components/post-list";
import { i18n } from "discourse-i18n";
import DiscourseReactionsReactionEmoji from "../../components/discourse-reactions-reaction-emoji";

export default <template>
  <PostList
    @posts={{@model}}
    @fetchMorePosts={{@controller.loadMore}}
    @emptyText={{i18n "notifications.empty"}}
    @additionalItemClasses="user-stream-item"
    @showUserInfo={{false}}
    class="user-stream"
  >
    <:belowPostItem as |reaction|>
      <DiscourseReactionsReactionEmoji @reaction={{reaction}} />
    </:belowPostItem>
  </PostList>
</template>
