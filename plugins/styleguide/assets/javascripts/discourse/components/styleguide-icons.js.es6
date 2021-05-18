import { afterRender } from "discourse-common/utils/decorators";

export default Ember.Component.extend({
  tagName: "section",
  classNames: ["styleguide-icons"],
  iconIds: [],

  init() {
    this._super(...arguments);
    this.setIconIds();
  },

  @afterRender
  setIconIds() {
    let symbols = document.querySelectorAll("#svg-sprites symbol");
    let ids = Array.from(symbols).mapBy("id");

    this.set("iconIds", ids);
  },
});
