import RestModel from "discourse/models/rest";
import User from "discourse/models/user";

export default class ChatMessage extends RestModel {}

ChatMessage.reopenClass({
  create(args) {
    args = args || {};
    this._initUserModel(args);
    return this._super(args);
  },

  _initUserModel(args) {
    if (args.user) {
      args.user = User.create(args.user);
    }
  },
});
