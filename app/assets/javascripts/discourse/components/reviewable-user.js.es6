import Component from "@ember/component";
import { default as discourseComputed } from "discourse-common/utils/decorators";

export default Component.extend({
  @discourseComputed("reviewable.user_fields")
  userFields(fields) {
    return this.site.collectUserFields(fields);
  }
});
