import Component from "@ember/component";

export default Component.extend({
  tagName: "section",
  classNames: ["styleguide-example"],
  value: null,

  init() {
    this._super(...arguments);
    this.value = this.initialValue;
  },
});
