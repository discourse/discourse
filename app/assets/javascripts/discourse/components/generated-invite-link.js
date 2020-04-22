import Component from "@ember/component";
export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    $(this.element.querySelector("input"))
      .select()
      .focus();
  }
});
