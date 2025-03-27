import RouteTemplate from "ember-route-template";
import PostList from "discourse/components/post-list/index";

export default RouteTemplate(
  <template>
    <ul class="user-stream">
      <PostList
        @posts={{@controller.model}}
        @urlPath="postUrl"
        @showUserInfo={{false}}
        @additionalItemClasses="user-stream-item"
        class="user-stream"
      />
    </ul>
  </template>
);
