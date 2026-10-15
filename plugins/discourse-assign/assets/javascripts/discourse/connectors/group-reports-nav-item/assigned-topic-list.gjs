import Component from "@glimmer/component";
import GroupAssignedMenuItem from "../../components/group-assigned-menu-item.gjs";

export default class AssignedTopicList extends Component {
  static shouldRender(args, context) {
    return (
      context.currentUser?.can_assign_globally &&
      args.group.can_show_assigned_tab &&
      args.group.can_see_members
    );
  }

  <template>
    <li class="group-reports-nav-item-outlet assigned-topic-list" ...attributes>
      <GroupAssignedMenuItem @group={{@group}} />
    </li>
  </template>
}
