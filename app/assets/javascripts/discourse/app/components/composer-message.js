import Component from "@ember/component";
import { getOwner } from "@ember/owner";
import deprecated from "discourse-common/lib/deprecated";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [":composer-popup", "message.extraClass"],

  @discourseComputed("message.templateName")
  layout(templateName) {
    return getOwner(this).lookup(`template:composer/${templateName}`);
  },

  actions: {
    closeMessage() {
      deprecated(
        'You should use `action=(closeMessage message)` instead of `action=(action "closeMessage")`',
        { id: "discourse.composer-message.closeMessage" }
      );
      this.closeMessage(this.message);
    },
  },
});
