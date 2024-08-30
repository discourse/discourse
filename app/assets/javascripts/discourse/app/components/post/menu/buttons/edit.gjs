import DButton from "discourse/components/d-button";

const PostMenuEditButton = <template>
  {{#if @transformedPost.canEdit}}
    <DButton
      class="edit create"
      ...attributes
      @icon={{if @transformedPost.wiki "far-edit" "pencil-alt"}}
      @title="post.controls.edit"
      @label={{if @properties.showLabel "post.controls.edit_action"}}
      @action={{@action}}
    />
  {{/if}}
</template>;

export default PostMenuEditButton;
