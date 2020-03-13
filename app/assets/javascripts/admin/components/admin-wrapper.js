import Component from "@ember/component";
export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    $("body").addClass("admin-interface");
  },

  willDestroyElement() {
    this._super(...arguments);
    $("body").removeClass("admin-interface");
  }
});
