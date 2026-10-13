import PostList from "discourse/components/post-list";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { i18n } from "discourse-i18n";
import DiscourseReactionsReactionEmoji from "../../components/discourse-reactions-reaction-emoji";

export default <template>
  {{#if @controller.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}
  <PostList
    class="user-stream"
    @additionalItemClasses="user-stream-item"
    @emptyText={{i18n "notifications.empty"}}
    @fetchMorePosts={{@controller.loadMore}}
    @posts={{@model}}
    @showUserInfo={{false}}
    @titlePath="titleHtml"
  >
    <:abovePostItemExcerpt as |reaction|>
      <DiscourseReactionsReactionEmoji @reaction={{reaction}} />
    </:abovePostItemExcerpt>
  </PostList>
</template>
