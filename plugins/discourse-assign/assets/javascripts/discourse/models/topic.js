import { Assignment } from "./assignment.js";

export function extendTopicModel(api) {
  api.addModelField("topic", "assigned_to_group");
  api.addModelField("topic", "assigned_to_group_id");
  api.addModelField("topic", "assigned_to_user");
  api.addModelField("topic", "assigned_to_user_id");
  api.addModelField("topic", "assignment_note");
  api.addModelField("topic", "assignment_status");
  api.addModelField("topic", "can_assign");
  api.addModelField("topic", "topic_assignments");
  api.addModelField("topic", "indirectly_assigned_to");

  api.addModelMethod("topic", "assignees", function () {
    const result = [];

    if (this.topic_assignments) {
      result.push(
        ...this.topic_assignments.map((assignment) => assignment.assigned_to)
      );
    } else if (this.assigned_to_user || this.assigned_to_group) {
      result.push(this.assigned_to_user || this.assigned_to_group);
    }

    const postAssignees = this.assignedPosts().map((p) => p.assigned_to);
    result.push(...postAssignees);
    return result;
  });

  api.addModelMethod("topic", "uniqueAssignees", function () {
    const map = new Map();
    this.assignees().forEach((user) =>
      map.set(
        user.username ? `user:${user.username}` : `group:${user.name}`,
        user
      )
    );
    return [...map.values()];
  });

  api.addModelMethod("topic", "assignedPosts", function () {
    if (!this.indirectly_assigned_to) {
      return [];
    }

    return Object.entries(this.indirectly_assigned_to).map(([key, value]) => {
      value.postId = key;
      return value;
    });
  });

  api.addModelMethod("topic", "assignments", function () {
    return [this.topicAssignment(), ...this.postAssignments()].filter(
      (item) => item != null
    );
  });

  api.addModelMethod("topic", "postAssignments", function () {
    if (!this.indirectly_assigned_to) {
      return [];
    }

    return Object.entries(this.indirectly_assigned_to).map(([key, value]) => {
      value.postId = key;
      return Assignment.fromPost(value);
    });
  });

  api.addModelMethod("topic", "topicAssignment", function () {
    return Assignment.fromTopic(this);
  });

  api.addModelMethod("topic", "isAssigned", function () {
    return this.topic_assignments !== undefined
      ? this.topic_assignments.length > 0
      : this.assigned_to_user || this.assigned_to_group;
  });

  api.addModelMethod("topic", "isAssignedTo", function (user) {
    return this.topic_assignments !== undefined
      ? this.topic_assignments.some(
          (assignment) =>
            assignment.assigned_to_type === "User" &&
            assignment.assigned_to.username === user.username
        )
      : this.assigned_to_user?.username === user.username;
  });

  api.addModelMethod("topic", "hasAssignedPosts", function () {
    return !!this.postAssignments().length;
  });
}
