import Component from "@ember/component";
import { getOwner } from "@ember/application";
import { gt } from "@ember/object/computed";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import { TOPIC_TYPE } from "../lib/presence-manager";

export default Component.extend({
  topic: null,
  presenceManager: null,

  init() {
    this._super(...arguments);
    this.set("presenceManager", getOwner(this).lookup("presence-manager:main"));
  },

  @discourseComputed("topic.id")
  users(topicId) {
    return this.presenceManager.users(topicId);
  },

  shouldDisplay: gt("users.length", 0),

  @on("didInsertElement")
  subscribe() {
    this.presenceManager.subscribe(this.get("topic.id"), TOPIC_TYPE);
  },

  @on("willDestroyElement")
  _destroyed() {
    this.presenceManager.unsubscribe(this.get("topic.id"), TOPIC_TYPE);
  }
});
