import PostList from "discourse/components/post-list/index";

export default <template>
  <ul class="user-stream">
    <PostList
      @posts={{@controller.model.content}}
      @urlPath="postUrl"
      @showUserInfo={{false}}
      @additionalItemClasses="user-stream-item"
      class="user-stream"
    />
  </ul>
</template>
