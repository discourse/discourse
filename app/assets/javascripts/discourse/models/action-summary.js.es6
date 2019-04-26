import { ajax } from "discourse/lib/ajax";
import RestModel from "discourse/models/rest";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default RestModel.extend({
  canToggle: Ember.computed.or("can_undo", "can_act"),

  // Remove it
  removeAction: function() {
    this.setProperties({
      acted: false,
      count: this.get("count") - 1,
      can_act: true,
      can_undo: false
    });
  },

  togglePromise(post) {
    return this.get("acted") ? this.undo(post) : this.act(post);
  },

  toggle(post) {
    if (!this.get("acted")) {
      this.act(post);
      return true;
    } else {
      this.undo(post);
      return false;
    }
  },

  // Perform this action
  act(post, opts) {
    if (!opts) opts = {};

    const action = this.get("actionType.name_key");

    // Mark it as acted
    this.setProperties({
      acted: true,
      count: this.get("count") + 1,
      can_act: false,
      can_undo: true
    });

    if (action === "notify_moderators" || action === "notify_user") {
      this.set("can_undo", false);
      this.set("can_defer_flags", false);
    }

    // Create our post action
    const self = this;
    return ajax("/post_actions", {
      type: "POST",
      data: {
        id: this.get("flagTopic") ? this.get("flagTopic.id") : post.get("id"),
        post_action_type_id: this.get("id"),
        message: opts.message,
        is_warning: opts.isWarning,
        take_action: opts.takeAction,
        flag_topic: this.get("flagTopic") ? true : false
      },
      returnXHR: true
    })
      .then(function(data) {
        if (!self.get("flagTopic")) {
          post.updateActionsSummary(data.result);
        }
        const remaining = parseInt(
          data.xhr.getResponseHeader("Discourse-Actions-Remaining") || 0
        );
        const max = parseInt(
          data.xhr.getResponseHeader("Discourse-Actions-Max") || 0
        );
        return { acted: true, remaining, max };
      })
      .catch(function(error) {
        popupAjaxError(error);
        self.removeAction(post);
      });
  },

  // Undo this action
  undo(post) {
    this.removeAction(post);

    // Remove our post action
    return ajax("/post_actions/" + post.get("id"), {
      type: "DELETE",
      data: { post_action_type_id: this.get("id") }
    }).then(result => {
      post.updateActionsSummary(result);
      return { acted: false };
    });
  },

  deferFlags(post) {
    return ajax("/post_actions/defer_flags", {
      type: "POST",
      data: { post_action_type_id: this.get("id"), id: post.get("id") }
    }).then(() => this.set("count", 0));
  }
});
