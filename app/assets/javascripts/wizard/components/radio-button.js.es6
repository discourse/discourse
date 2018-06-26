import { observes, on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "label",

  click(e) {
    e.preventDefault();
    this.sendAction("onChange", this.get("radioValue"));
  },

  @observes("value")
  @on("init")
  updateVal() {
    const checked = this.get("value") === this.get("radioValue");
    Ember.run.next(() => this.$("input[type=radio]").prop("checked", checked));
  }
});
