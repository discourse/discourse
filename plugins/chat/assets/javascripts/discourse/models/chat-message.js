import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
import EmberObject from "@ember/object";

export default class ChatMessage extends RestModel {}

ChatMessage.reopenClass({
  create(args = {}) {
    this._initReactions(args);
    this._initUserModel(args);

    return this._super(args);
  },

  _initReactions(args) {
    args.reactions = EmberObject.create(args.reactions || {});
  },

  _initUserModel(args) {
    if (!args.user || args.user instanceof User) {
      return;
    }

    args.user = User.create(args.user);
  },
});
