import discourseComputed, { on } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { TOPIC_TYPE } from "discourse/plugins/discourse-presence/discourse/lib/presence";
import { gt } from "@ember/object/computed";
import { inject as service } from "@ember/service";

export default Component.extend({
  topic: null,
  topicId: null,
  presenceManager: service(),

  @discourseComputed("topic.id")
  users(topicId) {
    return this.presenceManager.users(topicId);
  },

  shouldDisplay: gt("users.length", 0),

  didReceiveAttrs() {
    this._super(...arguments);
    if (this.topicId) {
      this.presenceManager.unsubscribe(this.topicId, TOPIC_TYPE);
    }
    this.set("topicId", this.get("topic.id"));
  },

  @on("didInsertElement")
  subscribe() {
    this.set("topicId", this.get("topic.id"));
    this.presenceManager.subscribe(this.get("topic.id"), TOPIC_TYPE);
  },

  @on("willDestroyElement")
  _destroyed() {
    this.presenceManager.unsubscribe(this.get("topic.id"), TOPIC_TYPE);
  },
});
