import DButton from "discourse/components/d-button";

const PostMenuShareButton = <template>
  <DButton
    class="share"
    ...attributes
    @icon="d-post-share"
    @title="post.controls.share"
    @label={{if @showLabel "post.controls.share_action"}}
    @action={{@action}}
  />
</template>;

export default PostMenuShareButton;
