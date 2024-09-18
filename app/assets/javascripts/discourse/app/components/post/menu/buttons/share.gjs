import DButton from "discourse/components/d-button";

const PostMenuShareButton = <template>
  <DButton
    class="share"
    ...attributes
    @action={{@buttonActions.share}}
    @icon="d-post-share"
    @label={{if @showLabel "post.controls.share_action"}}
    @title="post.controls.share"
  />
</template>;

export default PostMenuShareButton;
