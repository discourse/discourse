<ul class="user-stream">
  <PostList
    @posts={{this.model}}
    @urlPath="postUrl"
    @showUserInfo={{false}}
    @additionalItemClasses="user-stream-item"
    class="user-stream"
  />
</ul>