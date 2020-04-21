import { throttle } from "@ember/runloop";
import Component from "@ember/component";
import { equal, gt, alias } from "@ember/object/computed";
import { observes, on } from "discourse-common/utils/decorators";
import { REPLYING, CLOSED } from "../lib/presence-manager";

export default Component.extend({
  // Passed in variables
  action: null,
  post: null,
  topic: null,
  reply: null,
  title: null,

  presenceManager: alias("topic.presenceManager"),
  users: alias("presenceManager.users"),
  shouldDisplay: gt("users.length", 0),
  isReply: equal("action", "reply"),

  @on("didInsertElement")
  subscribe() {
    this.get("presenceManager").subscribe();
  },

  @observes("reply", "title")
  typing() {
    throttle(this, this.get("presenceManager").publish, REPLYING, 10000);
  },

  @on("willDestroyElement")
  composerClosing() {
    this.get("presenceManager").publish(CLOSED);
  }
});
