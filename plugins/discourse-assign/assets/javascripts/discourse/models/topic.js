import { tracked } from "@glimmer/tracking";
import { Assignment } from "./assignment";

export function extendTopicModel(api) {
  api.modifyClass(
    "model:topic",
    (Superclass) =>
      class extends Superclass {
        @tracked assigned_to_group;
        @tracked assigned_to_group_id;
        @tracked assigned_to_user;
        @tracked assigned_to_user_id;
        @tracked assignment_note;
        @tracked assignment_status;
        @tracked indirectly_assigned_to;

        assignees() {
          const result = [];

          if (this.assigned_to_user) {
            result.push(this.assigned_to_user);
          }

          const postAssignees = this.assignedPosts().map((p) => p.assigned_to);
          result.push(...postAssignees);
          return result;
        }

        uniqueAssignees() {
          const map = new Map();
          this.assignees().forEach((user) => map.set(user.username, user));
          return [...map.values()];
        }

        assignedPosts() {
          if (!this.indirectly_assigned_to) {
            return [];
          }

          return Object.entries(this.indirectly_assigned_to).map(
            ([key, value]) => {
              value.postId = key;
              return value;
            }
          );
        }

        assignments() {
          return [this.topicAssignment(), ...this.postAssignments()].compact();
        }

        postAssignments() {
          if (!this.indirectly_assigned_to) {
            return [];
          }

          return Object.entries(this.indirectly_assigned_to).map(
            ([key, value]) => {
              value.postId = key;
              return Assignment.fromPost(value);
            }
          );
        }

        topicAssignment() {
          return Assignment.fromTopic(this);
        }

        isAssigned() {
          return this.assigned_to_user || this.assigned_to_group;
        }

        isAssignedTo(user) {
          return this.assigned_to_user?.username === user.username;
        }

        hasAssignedPosts() {
          return !!this.postAssignments().length;
        }
      }
  );
}
