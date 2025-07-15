import Component from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import GroupAssignedMenuItem from "../../components/group-assigned-menu-item";

@tagName("li")
@classNames("group-reports-nav-item-outlet", "assigned-topic-list")
export default class AssignedTopicList extends Component {
  static shouldRender(args, context) {
    return (
      context.currentUser?.can_assign &&
      args.group.can_show_assigned_tab &&
      args.group.assignment_count > 0
    );
  }

  <template><GroupAssignedMenuItem @group={{this.group}} /></template>
}
