/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import GroupAssignedMenuItem from "../../components/group-assigned-menu-item";

@tagName("")
export default class AssignedTopicList extends Component {
  static shouldRender(args, context) {
    return (
      context.currentUser?.can_assign &&
      args.group.can_show_assigned_tab &&
      args.group.assignment_count > 0
    );
  }

  <template>
    <li class="group-reports-nav-item-outlet assigned-topic-list" ...attributes>
      <GroupAssignedMenuItem @group={{this.group}} />
    </li>
  </template>
}
