import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  @discourseComputed("field.value")
  showStaffCount: staffCount => staffCount > 1
});
