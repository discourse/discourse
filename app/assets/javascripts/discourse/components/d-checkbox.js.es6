import { on } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "label",

  @on("didInsertElement")
  _init() {
    const checked = this.get("checked");
    if (checked && checked !== "false") {
      this.$("input").prop("checked", true);
    }

    // In Ember 13.3 we can use action on the checkbox `{{input}}` but not in 1.11
    this.$("input").on("click.d-checkbox", () => {
      Ember.run.scheduleOnce("afterRender", () =>
        this.change(this.$("input").prop("checked"))
      );
    });
  },

  @on("willDestroyElement")
  _clear() {
    this.$("input").off("click.d-checkbox");
  }
});
