import RestModel from "discourse/models/rest";
import Singleton from "discourse/mixins/singleton";
import deprecated from "discourse-common/lib/deprecated";

// A data model representing current session data. You can put transient
// data here you might want later. It is not stored or serialized anywhere.
const Session = RestModel.extend({
  init: function() {
    this.set("highestSeenByTopic", {});
  }
});

Session.reopenClass(Singleton);

Object.defineProperty(Discourse, "Session", {
  get() {
    deprecated("Import the Session object instead of using Discourse.Session", {
      since: "2.4.0",
      dropFrom: "2.5.0"
    });
    return Session;
  }
});
export default Session;
