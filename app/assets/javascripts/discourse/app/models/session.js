import Singleton from "discourse/mixins/singleton";
import RestModel from "discourse/models/rest";

// A data model representing current session data. You can put transient
// data here you might want later. It is not stored or serialized anywhere.
export default class Session extends RestModel.extend().reopenClass(Singleton) {
  hasFocus = null;

  init() {
    this.set("highestSeenByTopic", {});
  }
}
