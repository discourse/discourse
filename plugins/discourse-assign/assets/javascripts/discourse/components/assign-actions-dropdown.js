import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@selectKitOptions({
  icon: null,
  translatedNone: "...",
  showFullTitle: true,
})
@classNames("assign-actions-dropdown")
export default class AssignActionsDropdown extends DropdownSelectBoxComponent {
  headerIcon = null;
  allowInitialValueMutation = false;
  showFullTitle = true;

  computeContent() {
    let options = [];
    if (this.assignee) {
      options = options.concat([
        {
          id: "unassign",
          icon: this.group ? "group-times" : "user-xmark",
          name: i18n("discourse_assign.unassign.title"),
          description: i18n("discourse_assign.unassign.help", {
            username: this.assignee,
          }),
        },
        {
          id: "reassign",
          icon: "users",
          name: i18n("discourse_assign.reassign.title"),
          description: i18n("discourse_assign.reassign.help"),
        },
      ]);
    }

    if (this.topic.indirectly_assigned_to) {
      Object.entries(this.topic.indirectly_assigned_to).forEach((entry) => {
        const [postId, assignment_map] = entry;
        const assignee = assignment_map.assigned_to;
        options = options.concat({
          id: `unassign_post_${postId}`,
          icon: assignee.username ? "user-xmark" : "group-times",
          name: i18n("discourse_assign.unassign_post.title"),
          description: i18n("discourse_assign.unassign_post.help", {
            username: assignee.username || assignee.name,
          }),
        });
      });
    }
    return options;
  }

  @action
  onChange(id) {
    switch (id) {
      case "unassign":
        this.unassign(this.topic.id);
        break;
      case "reassign":
        this.reassign(this.topic, this.assignee);
        break;
    }
    const postId = id.match(/unassign_post_(\d+)/)?.[1];
    if (postId) {
      this.unassign(postId, "Post");
    }
  }
}
