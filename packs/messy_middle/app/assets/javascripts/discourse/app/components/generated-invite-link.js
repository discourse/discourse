import Component from "@ember/component";
export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    const invite = this.element.querySelector(".invite-link-input");
    invite.focus();
    invite.select();
  },
});
