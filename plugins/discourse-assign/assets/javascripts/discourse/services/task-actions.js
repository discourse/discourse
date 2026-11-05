import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { manuallyTrack } from "discourse/lib/tracked-tools";
import AssignUser from "../components/modal/assign-user.gjs";
import EditTopicAssignments from "../components/modal/edit-topic-assignments.gjs";
import assignmentPayload from "../lib/assignment-payload.js";

export default class TaskActions extends Service {
  @service modal;
  @service siteSettings;

  @tracked suggestionsRevision = 0;
  #refreshVersions = new Map();
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

  async removeAssignment(id, topic) {
    await ajax(`/assign/assignments/${id}`, { type: "DELETE" });
    if (topic) {
      await this.refreshTopicAssignments(topic);
    }
  }

  async refreshTopicAssignments(topic) {
    const revision = (this.#refreshVersions.get(topic.id) || 0) + 1;
    this.#refreshVersions.set(topic.id, revision);
    const result = await ajax(`/assign/topics/${topic.id}/assignments`);
    if (this.#refreshVersions.get(topic.id) === revision) {
      this.#applyTopicAssignments(topic, result);
    }
    return result;
  }

  async replaceTopicAssignments(topic, assignments, version) {
    const revision = (this.#refreshVersions.get(topic.id) || 0) + 1;
    this.#refreshVersions.set(topic.id, revision);
    const result = await ajax(`/assign/topics/${topic.id}/assignments`, {
      type: "PUT",
      contentType: "application/json",
      data: JSON.stringify({
        expected_version: version,
        assignments: assignments.map((assignment) => ({
          id: assignment.id,
          ...assignmentPayload(assignment),
        })),
      }),
    });
    if (this.#refreshVersions.get(topic.id) === revision) {
      this.#applyTopicAssignments(topic, result);
    }
    return result;
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
    if (
      targetType === "Topic" &&
      (this.siteSettings.assign_allow_multiple_topic_assignees ||
        target.topic_assignments?.length > 1)
    ) {
      return this.modal.show(EditTopicAssignments, {
        model: { topic: target, onSuccess },
      });
    }
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

  #applyTopicAssignments(topic, result) {
    topic.topic_assignments = result.topic_assignments;
    const representative = result.topic_assignments[0];
    topic.assigned_to_user =
      representative?.assigned_to_type === "User"
        ? representative.assigned_to
        : null;
    topic.assigned_to_group =
      representative?.assigned_to_type === "Group"
        ? representative.assigned_to
        : null;
    topic.assignment_note = representative?.note;
    topic.assignment_status = representative?.status;
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
