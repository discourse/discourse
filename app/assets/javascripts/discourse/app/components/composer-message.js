import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { getOwner } from "discourse-common/lib/get-owner";
import { action } from "@ember/object";

export default Component.extend({
  classNameBindings: [":composer-popup", "hidden", "message.extraClass"],

  @discourseComputed("message.templateName")
  layout(templateName) {
    return getOwner(this).lookup(`template:composer/${templateName}`);
  },

  @action
  closeMessage() {
    this.closeMessage(this.message);
  },
});
