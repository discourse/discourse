import Component from "@ember/component";
import { gt } from "@ember/object/computed";
import { inject as service } from "@ember/service";
import discourseComputed, { on } from "discourse-common/utils/decorators";
import { TOPIC_TYPE } from "discourse/plugins/discourse-presence/discourse/lib/presence";

export default Component.extend({
  topic: null,
  presenceManager: service(),

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
