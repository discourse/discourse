import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { getOwner } from "discourse-common/lib/get-owner";

export default Component.extend({
  classNameBindings: [":composer-popup", ":hidden", "message.extraClass"],

  @computed("message.templateName")
  layout(templateName) {
    return getOwner(this).lookup(`template:composer/${templateName}`);
  },

  didInsertElement() {
    this._super(...arguments);
    this.element.style.display = "block";
  },

  actions: {
    closeMessage() {
      this.closeMessage(this.message);
    }
  }
});
