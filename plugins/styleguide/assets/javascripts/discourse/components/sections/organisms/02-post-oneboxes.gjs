import Post from "discourse/components/post";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default <template>
  <StyleguideExample @title="Wikipedia onebox">
    <Post @canCreatePost={{true}} @post={{@dummy.oneboxPosts.wikipedia}} />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Open">
    <Post @canCreatePost={{true}} @post={{@dummy.oneboxPosts.githubPrOpen}} />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Approved">
    <Post
      @canCreatePost={{true}}
      @post={{@dummy.oneboxPosts.githubPrApproved}}
    />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Changes Requested">
    <Post
      @canCreatePost={{true}}
      @post={{@dummy.oneboxPosts.githubPrChangesRequested}}
    />
  </StyleguideExample>

  <StyleguideExample @title="GitHub Pull Request - Merged">
    <Post @canCreatePost={{true}} @post={{@dummy.oneboxPosts.githubPrMerged}} />
  </StyleguideExample>
</template>
