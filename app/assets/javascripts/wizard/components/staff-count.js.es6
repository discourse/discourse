import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  @computed("field.value")
  showStaffCount: staffCount => staffCount > 1
});
