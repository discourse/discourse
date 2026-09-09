import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class AssignedToPost extends Component {
  @service taskActions;
  @service siteSettings;

  get nameOrUsername() {
    if (this.siteSettings.prioritize_full_name_in_ux) {
      return this.args.assignedToUser.name || this.args.assignedToUser.username;
    } else {
      return this.args.assignedToUser.username;
    }
  }

  get canAssign() {
    return this.args.post.can_assign;
  }

  @action
  unassign() {
    this.taskActions.unassignPost(this.args.post);
  }

  @action
  editAssignment() {
    this.taskActions.showAssignPostModal(this.args.post);
  }

  <template>
    {{#if @assignedToUser}}
      {{dIcon "user-plus"}}
    {{else}}
      {{dIcon "group-plus"}}
    {{/if}}

    <span class="assign-text">
      {{i18n "discourse_assign.assigned_to"}}
    </span>

    <a class="assigned-to-username" href={{@href}}>
      {{#if @assignedToUser}}
        {{this.nameOrUsername}}
      {{else}}
        {{@assignedToGroup.name}}
      {{/if}}
    </a>

    {{#if this.canAssign}}
      <DMenu
        class="btn-transparent more-button"
        @autofocus={{true}}
        @icon="ellipsis"
        @identifier="post-assign-menu"
      >
        <DDropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              class="btn-transparent unassign-btn"
              @action={{this.unassign}}
              @icon="user-plus"
              @label="discourse_assign.unassign.title"
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="btn-transparent edit-assignment-btn"
              @action={{this.editAssignment}}
              @icon="group-plus"
              @label="discourse_assign.reassign.title_w_ellipsis"
            />
          </dropdown.item>
        </DDropdownMenu>
      </DMenu>
    {{/if}}
  </template>
}
