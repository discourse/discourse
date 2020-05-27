import EmberObject from "@ember/object";
import { isTesting } from "@ember/debug";

export default EmberObject.create({
  reload() {
    if (!isTesting()) {
      location.reload();
    }
  }
});
