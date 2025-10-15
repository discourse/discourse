import PostList from "discourse/components/post-list/index";

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
