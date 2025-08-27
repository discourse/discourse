import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import CustomReaction from "../models/discourse-reactions-custom-reaction";

export default class UserActivityReactions extends Controller {
  @service siteSettings;
  @controller application;

  @tracked canLoadMore = true;
  @tracked loading = false;
  @tracked beforeLikeId = null;
  @tracked beforeReactionUserId = null;

  #getLastIdFrom(array) {
    return array.length ? array[array.length - 1].get("id") : null;
  }

  #updateBeforeIds(reactionUsers) {
    if (this.includeLikes) {
      const mainReaction =
        this.siteSettings.discourse_reactions_reaction_for_like;
      const [likes, reactions] = reactionUsers.reduce(
        (memo, elem) => {
          if (elem.reaction.reaction_value === mainReaction) {
            memo[0].push(elem);
          } else {
            memo[1].push(elem);
          }

          return memo;
        },
        [[], []]
      );

      this.beforeLikeId = this.#getLastIdFrom(likes);
      this.beforeReactionUserId = this.#getLastIdFrom(reactions);
    } else {
      this.beforeReactionUserId = this.#getLastIdFrom(reactionUsers);
    }
  }

  @action
  loadMore() {
    if (!this.canLoadMore || this.loading) {
      return;
    }

    this.loading = true;
    const reactionUsers = this.model;

    if (!this.beforeReactionUserId) {
      this.#updateBeforeIds(reactionUsers);
    }

    const opts = {
      actingUsername: this.actingUsername,
      includeLikes: this.includeLikes,
      beforeLikeId: this.beforeLikeId,
      beforeReactionUserId: this.beforeReactionUserId,
    };

    CustomReaction.findReactions(this.reactionsUrl, this.username, opts)
      .then((newReactionUsers) => {
        reactionUsers.addObjects(newReactionUsers);
        this.#updateBeforeIds(newReactionUsers);
        if (newReactionUsers.length === 0) {
          this.canLoadMore = false;
        }
      })
      .finally(() => {
        this.loading = false;
      });
  }
}
