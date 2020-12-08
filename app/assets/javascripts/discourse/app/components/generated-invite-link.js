import Component from "@ember/component";
export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    $(this.element.querySelector(".invite-link-input")).select().focus();
  },
});
