import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";

export class Assignment extends EmberObject {
  static fromTopic(topic) {
    const assignment = new Assignment();
    assignment.id = 0;
    assignment.username = topic.assigned_to_user?.username;
    assignment.groupName = topic.assigned_to_group?.name;
    assignment.status = topic.assignment_status;
    assignment.note = topic.assignment_note;
    assignment.targetId = topic.id;
    assignment.targetType = "Topic";
    return assignment;
  }

  static fromPost(post) {
    const assignment = new Assignment();
    assignment.username = post.assigned_to.username;
    assignment.name = post.assigned_to.name;
    assignment.groupName = post.assigned_to.name;
    assignment.status = post.assignment_status;
    assignment.note = post.assignment_note;
    assignment.targetId = post.postId;
    assignment.targetType = "Post";
    assignment.postNumber = post.post_number;
    assignment.id = post.post_number;
    return assignment;
  }

  // to-do rename to groupName, some components use both this model
  // and models from server, that's why we have to call it "group_name" now
  @tracked group_name;
  @tracked isEdited = false;
  @tracked name;
  @tracked note;
  @tracked status;
  @tracked username;
  targetId;
  targetType;
  postNumber;
}
