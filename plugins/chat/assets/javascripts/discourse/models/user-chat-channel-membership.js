import RestModel from "discourse/models/rest";
import { tracked } from "@glimmer/tracking";
import User from "discourse/models/user";
export default class UserChatChannelMembership extends RestModel {
  @tracked following = false;
  @tracked muted = false;
  @tracked unread_count = 0;
  @tracked unread_mentions = 0;
  @tracked desktop_notification_level = null;
  @tracked mobile_notification_level = null;
  @tracked last_read_message_id = null;
}

UserChatChannelMembership.reopenClass({
  create(args) {
    args = args || {};
    this._initUser(args);
    return this._super(args);
  },

  _initUser(args) {
    if (!args.user || args.user instanceof User) {
      return;
    }

    args.user = User.create(args.user);
  },
});
