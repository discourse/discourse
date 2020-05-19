import EmberObject from "@ember/object";
import DiscourseEnv from "discourse-common/addon/config/environment";

export default EmberObject.create({
  reload: function() {
    if (DiscourseEnv.environment !== "test") {
      location.reload();
    }
  }
});
