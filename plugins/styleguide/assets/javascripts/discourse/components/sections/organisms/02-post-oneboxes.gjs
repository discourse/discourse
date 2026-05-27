import Post from "discourse/components/post";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

<template>
  <StyleguideExample @title="Wikipedia onebox">
    <Post @post={{@dummy.oneboxPosts.wikipedia}} @canCreatePost={{true}} />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Open">
    <Post @post={{@dummy.oneboxPosts.githubPrOpen}} @canCreatePost={{true}} />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Approved">
    <Post
      @post={{@dummy.oneboxPosts.githubPrApproved}}
      @canCreatePost={{true}}
    />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Changes Requested">
    <Post
      @post={{@dummy.oneboxPosts.githubPrChangesRequested}}
      @canCreatePost={{true}}
    />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Merged">
    <Post @post={{@dummy.oneboxPosts.githubPrMerged}} @canCreatePost={{true}} />
  </StyleguideExample>
</template>
