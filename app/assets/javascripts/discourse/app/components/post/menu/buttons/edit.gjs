import DButton from "discourse/components/d-button";

const PostMenuEditButton = <template>
  {{#if @post.can_edit}}
    <DButton
      class="edit create"
      ...attributes
      @icon={{if @post.wiki "far-edit" "pencil-alt"}}
      @title="post.controls.edit"
      @label={{if @properties.showLabel "post.controls.edit_action"}}
      @action={{@action}}
    />
  {{/if}}
</template>;

export default PostMenuEditButton;
