import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { manuallyTrack } from "discourse/lib/tracked-tools";
import AssignUser from "../components/modal/assign-user.gjs";
import assignmentPayload from "../lib/assignment-payload.js";

export default class TaskActions extends Service {
  @service modal;

  @tracked suggestionsRevision = 0;
  #suggestionsByTarget = new Map();
  #suggestionsPromisesByTarget = new Map();

  suggestionsFor(targetId, targetType = "Topic") {
    manuallyTrack(this.suggestionsRevision);
    this.#ensureSuggestions(targetId, targetType);

    return (
      this.#suggestionsByTarget.get(
        this.#suggestionsKey(targetId, targetType)
      ) || null
    );
  }

  searchUrlFor(targetId, targetType = "Topic") {
    const query = new URLSearchParams(this.#targetParams(targetId, targetType));
    return query.size ? `/assign/search?${query}` : "/assign/search";
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
          ...assignmentPayload(model),
          target_id: model.target.id,
          target_type: model.targetType,
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
        ...assignmentPayload(assignment),
        target_id: assignment.targetId,
        target_type: assignment.targetType,
      },
    });
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
    const response = await ajax("/assign/suggestions", {
      data: this.#targetParams(targetId, targetType),
    });

    if (this.isDestroying) {
      return;
    }

    this.#suggestionsByTarget.set(key, [
      ...response.suggestions,
      ...response.groups,
    ]);
    this.#suggestionsPromisesByTarget.delete(key);
    this.suggestionsRevision++;
  }

  #targetParams(targetId, targetType) {
    return targetId ? { target_id: targetId, target_type: targetType } : {};
  }

  #suggestionsKey(targetId, targetType) {
    return targetId ? `${targetType}:${targetId}` : "default";
  }
}
