import PostList from "discourse/components/post-list/index";
import { i18n } from "discourse-i18n";

export default <template>
  <PostList
    @emptyText={{i18n "groups.empty.posts"}}
    @fetchMorePosts={{@controller.fetchMorePosts}}
    @posts={{@controller.model}}
    @titlePath="topic_html_title"
  />
</template>
