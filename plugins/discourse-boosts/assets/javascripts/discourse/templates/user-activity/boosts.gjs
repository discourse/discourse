import { htmlSafe } from "@ember/template";
import PostList from "discourse/components/post-list";
import avatar from "discourse/helpers/avatar";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default <template>
  {{#if @controller.canLoadMore}}
    {{hideApplicationFooter}}
  {{/if}}
  <PostList
    @posts={{@model}}
    @fetchMorePosts={{@controller.loadMore}}
    @emptyText={{i18n "notifications.empty"}}
    @additionalItemClasses="user-stream-item"
    @titlePath="titleHtml"
    class="user-stream"
  >
    <:belowPostItem as |boost|>
      <div class="discourse-boosts-activity__boost">
        <a
          href={{userPath boost.booster.username}}
          data-user-card={{boost.booster.username}}
          class="discourse-boosts-activity__avatar"
        >
          {{avatar boost.booster imageSize="tiny"}}
        </a>
        <span class="discourse-boosts-activity__cooked">{{htmlSafe
            boost.boost_cooked
          }}</span>
      </div>
    </:belowPostItem>
  </PostList>
</template>
