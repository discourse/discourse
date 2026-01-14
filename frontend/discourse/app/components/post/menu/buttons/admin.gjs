import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class PostMenuAdminButton extends Component {
  static shouldRender(args) {
    return (
      args.post.canManage || args.post.can_wiki || args.post.canEditStaffNotes
    );
  }

  <template>
    <DButton
      class="post-action-menu__admin show-post-admin-menu"
      ...attributes
      @action={{@buttonActions.openAdminMenu}}
      @forwardEvent={{true}}
      @icon="wrench"
      @label={{if @showLabel "post.controls.admin_action"}}
      @title="post.controls.admin"
    />
  </template>
}
