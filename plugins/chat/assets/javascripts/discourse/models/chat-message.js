import RestModel from "discourse/models/rest";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { tracked } from "@glimmer/tracking";
import User from "discourse/models/user";

export const REACTIONS = { add: "add", remove: "remove" };

export default class ChatMessage extends RestModel {
  @tracked selected;
  @tracked reactions;

  loadingReactions = [];

  // deep TrackedObject c.f. https://github.com/emberjs/ember.js/issues/18988#issuecomment-837670880
  init() {
    this._super(...arguments);
    this.reactions = new TrackedObject(this._reactions);
    Object.keys(this.reactions).forEach((emoji) => {
      this.reactions[emoji] = new TrackedObject(this.reactions[emoji]);
    });
  }

  get hasReactions() {
    return Object.values(this.reactions).some((r) => r.count > 0);
  }

  // TODO (martin) Not ideal, this should have a chat API controller endpoint
  // and be moved to that service.
  publishReaction(emoji, reactAction) {
    return ajax(`/chat/${this.chat_channel_id}/react/${this.id}`, {
      type: "PUT",
      data: {
        react_action: reactAction,
        emoji,
      },
    }).catch((errResult) => {
      popupAjaxError(errResult);
    });
  }

  updateReactionsList(emoji, reactAction, user, selfReacted) {
    if (this.reactions[emoji]) {
      if (
        selfReacted &&
        reactAction === REACTIONS.add &&
        this.reactions[emoji].reacted
      ) {
        // User is already has reaction added; do nothing
        return false;
      }

      let newCount =
        reactAction === REACTIONS.add
          ? this.reactions[emoji].count + 1
          : this.reactions[emoji].count - 1;

      this.reactions[emoji].count = newCount;
      if (selfReacted) {
        this.reactions[emoji].reacted = reactAction === REACTIONS.add;
      } else {
        this.reactions[emoji].users.pushObject(user);
      }
    } else {
      if (reactAction === REACTIONS.add) {
        this.reactions[emoji] = new TrackedObject({
          count: 1,
          reacted: selfReacted,
          users: selfReacted ? [] : [user],
        });
      }
    }
  }
}

ChatMessage.reopenClass({
  create(args = {}) {
    this._initReactions(args);
    this._initUserModel(args);

    return this._super(args);
  },

  _initReactions(args) {
    args._reactions = args.reactions || {};
    delete args.reactions;
  },

  _initUserModel(args) {
    if (!args.user || args.user instanceof User) {
      return;
    }

    args.user = User.create(args.user);
  },
});
