import PostList from "discourse/components/post-list";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { i18n } from "discourse-i18n";
import DiscourseReactionsReactionEmoji from "../../components/discourse-reactions-reaction-emoji";

export default <template>
  {{#if @controller.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}
  <PostList
    @posts={{@model}}
    @fetchMorePosts={{@controller.loadMore}}
    @emptyText={{i18n "notifications.empty"}}
    @additionalItemClasses="user-stream-item"
    @showUserInfo={{false}}
    class="user-stream"
  >
    <:abovePostItemExcerpt as |reaction|>
      <DiscourseReactionsReactionEmoji @reaction={{reaction}} />
    </:abovePostItemExcerpt>
  </PostList>
</template>
