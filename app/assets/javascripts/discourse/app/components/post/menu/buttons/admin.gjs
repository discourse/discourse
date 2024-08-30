import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";

const PostMenuAdminButton = <template>
  {{#if
    (or
      @transformedPost.canManage
      @transformedPost.canWiki
      @transformedPost.canEditStaffNotes
    )
  }}
    <DButton
      class="show-post-admin-menu"
      ...attributes
      @icon="wrench"
      @title="post.controls.admin"
      @label={{if @properties.showLabel "post.controls.admin_action"}}
      @action={{@action}}
      @forwardEvent={{true}}
    />
  {{/if}}
</template>;

export default PostMenuAdminButton;
