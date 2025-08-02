import { or } from "@ember/object/computed";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import RestModel from "discourse/models/rest";

// TODO (glimmer-post-stream) is this model still used?
export default class ActionSummary extends RestModel {
  @or("can_undo", "can_act") canToggle;

  // Remove it
  removeAction() {
    this.setProperties({
      acted: false,
      count: this.count - 1,
      can_act: true,
      can_undo: false,
    });
  }

  togglePromise(post) {
    return this.acted ? this.undo(post) : this.act(post);
  }

  toggle(post) {
    if (!this.acted) {
      this.act(post);
      return true;
    } else {
      this.undo(post);
      return false;
    }
  }

  // Perform this action
  act(post, opts) {
    if (!opts) {
      opts = {};
    }

    // Mark it as acted
    this.setProperties({
      acted: true,
      count: this.count + 1,
      can_act: false,
      can_undo: true,
    });

    // Create our post action
    return ajax("/post_actions", {
      type: "POST",
      data: {
        id: this.flagTopic ? this.get("flagTopic.id") : post.get("id"),
        post_action_type_id: this.id,
        message: opts.message,
        is_warning: opts.isWarning,
        take_action: opts.takeAction,
        queue_for_review: opts.queue_for_review,
        flag_topic: this.flagTopic ? true : false,
      },
      returnXHR: true,
    })
      .then((data) => {
        if (!this.flagTopic) {
          post.updateActionsSummary(data.result);
        }
        const remaining = parseInt(
          data.xhr.getResponseHeader("Discourse-Actions-Remaining") || 0,
          10
        );
        const max = parseInt(
          data.xhr.getResponseHeader("Discourse-Actions-Max") || 0,
          10
        );
        return { acted: true, remaining, max };
      })
      .catch((error) => {
        popupAjaxError(error);
        this.removeAction(post);
      });
  }

  // Undo this action
  undo(post) {
    this.removeAction(post);

    // Remove our post action
    return ajax("/post_actions/" + post.get("id"), {
      type: "DELETE",
      data: { post_action_type_id: this.id },
    }).then((result) => {
      post.updateActionsSummary(result);
      return { acted: false };
    });
  }
}
