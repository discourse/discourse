import singleton from "discourse/lib/singleton";
import RestModel from "discourse/models/rest";

// A data model representing current session data. You can put transient
// data here you might want later. It is not stored or serialized anywhere.
@singleton
export default class Session extends RestModel {
  hasFocus = null;

  init() {
    this.set("highestSeenByTopic", {});
  }
}
