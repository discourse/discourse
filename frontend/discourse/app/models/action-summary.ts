import { computed } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import type Post from "discourse/models/post";
import type PostActionType from "discourse/models/post-action-type";
import RestModel from "discourse/models/rest";
import type Topic from "discourse/models/topic";

/** Server summary fields and references assigned while hydrating post/topic actions. */
export interface ActionSummaryFields {
  id: number;
  count: number;
  acted?: boolean;
  can_act?: boolean;
  can_undo?: boolean;
  hidden?: boolean;
  actionType?: PostActionType;
  post?: Topic;
  /** Topic flag actions accept this topic in place of a post. */
  flagTopic?: Topic;
}

/** Options forwarded when creating a post or topic action. */
export interface ActionSummaryOptions {
  message?: string;
  isWarning?: boolean;
  takeAction?: boolean;
  queue_for_review?: boolean;
}

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface ActionSummary extends ActionSummaryFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class ActionSummary extends RestModel {
  @computed("can_undo", "can_act")
  get canToggle() {
    return this.can_undo || this.can_act;
  }

  /** Reverts the local summary; the legacy post argument is ignored. */
  removeAction(post?: Post | Topic): void;
  removeAction() {
    this.setProperties({
      acted: false,
      count: this.count - 1,
      can_act: true,
      can_undo: false,
    });
  }

  togglePromise(post: Post) {
    return this.acted ? this.undo(post) : this.act(post);
  }

  toggle(post: Post) {
    if (!this.acted) {
      this.act(post);
      return true;
    } else {
      this.undo(post);
      return false;
    }
  }

  /** Performs this action, rolling back the optimistic state if the request fails. */
  act(post: Post | Topic, opts?: ActionSummaryOptions) {
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
    // TODO(typescript-pending): ajax has no typed returnXHR response; remove when it does.
    return (
      ajax("/post_actions", {
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
      }) as Promise<{
        result: unknown;
        xhr: Pick<XMLHttpRequest, "getResponseHeader">;
      }>
    )
      .then((data): { acted: true; remaining: number; max: number } => {
        if (!this.flagTopic) {
          // Topic flag actions skip this post-only refresh.
          (post as Post).updateActionsSummary(data.result);
        }
        // The `|| 0` fallback is a number, which parseInt coerces.
        const remaining = parseInt(
          (data.xhr.getResponseHeader("Discourse-Actions-Remaining") ||
            0) as string,
          10
        );
        const max = parseInt(
          (data.xhr.getResponseHeader("Discourse-Actions-Max") || 0) as string,
          10
        );
        return { acted: true, remaining, max };
      })
      .catch((error: unknown): undefined => {
        popupAjaxError(error);
        this.removeAction(post);
      });
  }

  /** Undoes this action and refreshes the post summary from the response. */
  undo(post: Post) {
    this.removeAction(post);

    // Remove our post action
    return ajax("/post_actions/" + post.get("id"), {
      type: "DELETE",
      data: { post_action_type_id: this.id },
    }).then((result: unknown): { acted: false } => {
      post.updateActionsSummary(result);
      return { acted: false };
    });
  }
}
