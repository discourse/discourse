import { tracked } from "@glimmer/tracking";
import { inject as service } from "@ember/service";
import Category from "discourse/models/category";
import User from "discourse/models/user";
import ChatChannel from "discourse/plugins/chat/discourse/models/chat-channel";

export default class ChatChatable {
  static create(args = {}) {
    return new ChatChatable(args);
  }

  static createUser(model) {
    return new ChatChatable({
      type: "user",
      model,
      identifier: `u-${model.id}`,
    });
  }

  static createChannel(model) {
    return new ChatChatable({
      type: "channel",
      model,
      identifier: `c-${model.id}`,
    });
  }

  @service chatChannelsManager;

  @tracked identifier;
  @tracked type;
  @tracked model;
  @tracked enabled = true;
  @tracked tracking;

  constructor(args = {}) {
    this.identifier = args.identifier;
    this.type = args.type;

    switch (this.type) {
      case "channel":
        if (args.model.chatable?.users?.length === 1) {
          this.enabled = args.model.chatable?.users[0].has_chat_enabled;
        }

        if (args.model instanceof ChatChannel) {
          this.model = args.model;
          break;
        }

        this.model = ChatChannel.create(args.model);
        break;
      case "user":
        this.enabled = args.model.has_chat_enabled;

        if (args.model instanceof User) {
          this.model = args.model;
          break;
        }

        this.model = User.create(args.model);
        break;
    }
  }

  get isUser() {
    return this.type === "user";
  }

  get isCategory() {
    return this instanceof Category;
  }
}
