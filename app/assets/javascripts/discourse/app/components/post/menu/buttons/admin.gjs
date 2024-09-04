import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";

const PostMenuAdminButton = <template>
  {{#if (or @post.canManage @post.can_wiki @post.canEditStaffNotes)}}
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
