import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import AssignUser from "../components/modal/assign-user";

export default class TaskActions extends Service {
  @service modal;

  @tracked suggestionsRevision = 0;
  #allowedGroupsByTarget = new Map();
  #allowedGroupsForAssignmentByTarget = new Map();
  #suggestionsByTarget = new Map();
  #suggestionsPromisesByTarget = new Map();

  get suggestions() {
    return this.suggestionsFor();
  }

  get allowedGroups() {
    return this.allowedGroupsFor();
  }

  get allowedGroupsForAssignment() {
    return this.allowedGroupsForAssignmentFor();
  }

  suggestionsFor(targetId, targetType = "Topic") {
    this.suggestionsRevision;
    this.#ensureSuggestions(targetId, targetType);

    return (
      this.#suggestionsByTarget.get(
        this.#suggestionsKey(targetId, targetType)
      ) || null
    );
  }

  allowedGroupsFor(targetId, targetType = "Topic") {
    this.suggestionsRevision;
    this.#ensureSuggestions(targetId, targetType);

    return (
      this.#allowedGroupsByTarget.get(
        this.#suggestionsKey(targetId, targetType)
      ) || []
    );
  }

  allowedGroupsForAssignmentFor(targetId, targetType = "Topic") {
    this.suggestionsRevision;
    this.#ensureSuggestions(targetId, targetType);

    return (
      this.#allowedGroupsForAssignmentByTarget.get(
        this.#suggestionsKey(targetId, targetType)
      ) || []
    );
  }

  #ensureSuggestions(targetId, targetType) {
    const key = this.#suggestionsKey(targetId, targetType);

    if (
      this.#suggestionsByTarget.has(key) ||
      this.#suggestionsPromisesByTarget.has(key)
    ) {
      return;
    }

    this.#suggestionsPromisesByTarget.set(
      key,
      this.#fetchSuggestions(key, targetId, targetType)
    );
  }

  async #fetchSuggestions(key, targetId, targetType) {
    const data = {};

    if (targetId) {
      data.target_id = targetId;
      data.target_type = targetType;
    }

    const response = await ajax("/assign/suggestions", { data });

    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.#suggestionsByTarget.set(key, response.suggestions);
    this.#allowedGroupsByTarget.set(key, response.assign_allowed_on_groups);
    this.#allowedGroupsForAssignmentByTarget.set(
      key,
      response.assign_allowed_for_groups
    );
    this.#suggestionsPromisesByTarget.delete(key);
    this.suggestionsRevision++;
  }

  #suggestionsKey(targetId, targetType) {
    return targetId ? `${targetType}:${targetId}` : "default";
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

    // force the components tracking `topic.indirectly_assigned_to` to update
    // eslint-disable-next-line no-self-assign
    post.topic.indirectly_assigned_to = post.topic.indirectly_assigned_to;
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
      model.target.assigned_to_user = null;
    }

    if (isEmpty(model.group_name)) {
      model.target.assigned_to_group = null;
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
