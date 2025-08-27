import RouteTemplate from "ember-route-template";
import PostList from "discourse/components/post-list/index";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <PostList
      @posts={{@controller.model}}
      @titlePath="topic_html_title"
      @fetchMorePosts={{@controller.fetchMorePosts}}
      @emptyText={{i18n "groups.empty.posts"}}
    />
  </template>
);
