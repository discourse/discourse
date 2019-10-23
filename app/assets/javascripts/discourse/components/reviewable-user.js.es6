import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Component.extend({
  @computed("reviewable.user_fields")
  userFields(fields) {
    return this.site.collectUserFields(fields);
  }
});
