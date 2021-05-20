import Component from "@ember/component";
export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    document.querySelector("html").classList.add("admin-area");
    document.querySelector("body").classList.add("admin-interface");
  },

  willDestroyElement() {
    this._super(...arguments);
    document.querySelector("html").classList.remove("admin-area");
    document.querySelector("body").classList.remove("admin-interface");
  },
});
