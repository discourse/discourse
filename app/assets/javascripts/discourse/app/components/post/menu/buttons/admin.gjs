import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";

export default class PostMenuAdminButton extends Component {
  static shouldRender(post) {
    return post.canManage || post.can_wiki || post.canEditStaffNotes;
  }

  <template>
    {{#if @shouldRender}}
      <DButton
        class="show-post-admin-menu"
        ...attributes
        @action={{@action}}
        @forwardEvent={{true}}
        @icon="wrench"
        @label={{if @showLabel "post.controls.admin_action"}}
        @title="post.controls.admin"
      />
    {{/if}}
  </template>
}
