import DButton from "discourse/components/d-button";

const PostMenuCopyLinkButton = <template>
  <DButton
    class="post-action-menu__copy-link"
    ...attributes
    @icon="d-post-share"
    @title="post.controls.copy_title"
    @label={{if @showLabel "post.controls.copy_action"}}
    @action={{@action}}
  />
</template>;

export default PostMenuCopyLinkButton;
