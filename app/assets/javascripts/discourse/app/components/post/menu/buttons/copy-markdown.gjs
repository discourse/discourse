import DButton from "discourse/components/d-button";

const PostMenuCopyMarkdownButton = <template>
  <DButton
    class="post-action-menu__copy-markdown"
    ...attributes
    @action={{@buttonActions.copyMarkdown}}
    @icon="code"
    @label={{if @showLabel "post.controls.copy_markdown"}}
    @title="post.controls.copy_markdown_title"
  />
</template>;

export default PostMenuCopyMarkdownButton;
