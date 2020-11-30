import Component from "@ember/component";
import { and } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  @discourseComputed
  user() {
    return this.currentUser;
  },
  shouldShow: and("category.read_only_banner", "readOnly", "user"),
});
