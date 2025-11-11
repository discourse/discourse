import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

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
      {{icon "user-plus"}}
    {{else}}
      {{icon "group-plus"}}
    {{/if}}

    <span class="assign-text">
      {{i18n "discourse_assign.assigned_to"}}
    </span>

    <a href={{@href}} class="assigned-to-username">
      {{#if @assignedToUser}}
        {{this.nameOrUsername}}
      {{else}}
        {{@assignedToGroup.name}}
      {{/if}}
    </a>

    <DMenu
      @identifier="post-assign-menu"
      @icon="ellipsis"
      class="btn-flat more-button"
      @autofocus={{true}}
    >
      <DropdownMenu as |dropdown|>
        <dropdown.item>
          <DButton
            @action={{this.unassign}}
            @icon="user-plus"
            @label="discourse_assign.unassign.title"
            class="btn-transparent unassign-btn"
          />
        </dropdown.item>
        <dropdown.item>
          <DButton
            @action={{this.editAssignment}}
            @icon="group-plus"
            @label="discourse_assign.reassign.title_w_ellipsis"
            class="btn-transparent edit-assignment-btn"
          />
        </dropdown.item>
      </DropdownMenu>
    </DMenu>
  </template>
}
