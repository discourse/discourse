import Component from "@ember/component";
import layout from "discourse/templates/components/user-menu-wrapper";

export default Component.extend({
  layout,
  tagName: "",

  didInsertElement() {
    this._super(...arguments);
    this.appEvents.trigger("user-menu:rendered");
  },
});
