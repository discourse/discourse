import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { and } from "@ember/object/computed";

export default Component.extend({
  @discourseComputed
  user() {
    return this.currentUser;
  },
  shouldShow: and("category.read_only_banner", "readOnly", "user")
});
