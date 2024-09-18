import DButton from "discourse/components/d-button";

const PostMenuCopyLinkButton = <template>
  <DButton
    class="post-action-menu__copy-link"
    ...attributes
    @action={{@buttonActions.copyLink}}
    @icon="d-post-share"
    @label={{if @showLabel "post.controls.copy_action"}}
    @title="post.controls.copy_title"
  />
</template>;

export default PostMenuCopyLinkButton;
