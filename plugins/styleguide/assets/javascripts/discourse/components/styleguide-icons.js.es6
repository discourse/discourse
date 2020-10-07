import { later } from "@ember/runloop";

export default Ember.Component.extend({
  tagName: "section",
  classNames: ["styleguide-icons"],
  iconIDs: [],

  didInsertElement() {
    this._super(...arguments);

    later(() => {
      let IDs = $("#svg-sprites symbol")
        .map(function () {
          return this.id;
        })
        .get();

      this.set("iconIDs", IDs);
    }, 2000);
  },
});
