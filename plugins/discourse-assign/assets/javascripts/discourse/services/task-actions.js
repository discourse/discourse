import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import AssignUser from "../components/modal/assign-user";

export default class TaskActions extends Service {
  @service modal;

  @tracked allowedGroups;
  @tracked allowedGroupsForAssignment;
  #suggestionsPromise; // eslint-disable-line no-unused-private-class-members
  @tracked _suggestions;

  get suggestions() {
    if (this._suggestions) {
      return this._suggestions;
    }

    this.#suggestionsPromise ||= this.#fetchSuggestions();

    return null;
  }

  async #fetchSuggestions() {
    const data = await ajax("/assign/suggestions");

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this._suggestions = data.suggestions;
    this.allowedGroups = data.assign_allowed_on_groups;
    this.allowedGroupsForAssignment = data.assign_allowed_for_groups;
  }

  unassign(targetId, targetType = "Topic") {
    return ajax("/assign/unassign", {
      type: "PUT",
      data: {
        target_id: targetId,
        target_type: targetType,
      },
    });
  }

  async unassignPost(post) {
    await this.unassign(post.id, "Post");
    delete post.topic.indirectly_assigned_to[post.id];
  }

  showAssignModal(
    target,
    { isAssigned = false, targetType = "Topic", onSuccess }
  ) {
    return this.modal.show(AssignUser, {
      model: {
        reassign: isAssigned,
        username: target.assigned_to_user?.username,
        group_name: target.assigned_to_group?.name,
        status: target.assignment_status,
        target,
        targetType,
        onSuccess,
      },
    });
  }

  showAssignPostModal(post) {
    return this.showAssignModal(post, { targetType: "Post" });
  }

  reassignUserToTopic(user, target, targetType = "Topic") {
    return ajax("/assign/assign", {
      type: "PUT",
      data: {
        username: user.username,
        target_id: target.id,
        target_type: targetType,
        status: target.assignment_status,
      },
    });
  }

  async assign(model) {
    if (isEmpty(model.username)) {
      model.target.set("assigned_to_user", null);
    }

    if (isEmpty(model.group_name)) {
      model.target.set("assigned_to_group", null);
    }

    let path = "/assign/assign";
    if (isEmpty(model.username) && isEmpty(model.group_name)) {
      path = "/assign/unassign";
    }

    try {
      await ajax(path, {
        type: "PUT",
        data: {
          username: model.username,
          group_name: model.group_name,
          target_id: model.target.id,
          target_type: model.targetType,
          note: model.note,
          status: model.status,
        },
      });

      model.onSuccess?.();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async putAssignment(assignment) {
    await ajax("/assign/assign", {
      type: "PUT",
      data: {
        username: assignment.username,
        group_name: assignment.group_name,
        target_id: assignment.targetId,
        target_type: assignment.targetType,
        note: assignment.note,
        status: assignment.status,
      },
    });
  }
}
