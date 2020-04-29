import Component from "@ember/component";
import { gt, readOnly } from "@ember/object/computed";
import { on } from "discourse-common/utils/decorators";

export default Component.extend({
  topic: null,

  presenceManager: readOnly("topic.presenceManager"),
  users: readOnly("presenceManager.users"),
  shouldDisplay: gt("users.length", 0),

  @on("didInsertElement")
  subscribe() {
    this.presenceManager.subscribe();
  },

  @on("willDestroyElement")
  _destroyed() {
    this.presenceManager.unsubscribe();
  }
});
