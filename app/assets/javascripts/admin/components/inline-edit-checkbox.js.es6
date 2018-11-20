import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  init() {
    this._super();
    this.set("checkedInternal", this.get("checked"));
  },

  classNames: ["inline-edit"],

  @observes("checked")
  checkedChanged() {
    this.set("checkedInternal", this.get("checked"));
  },

  @computed("labelKey")
  label(key) {
    return I18n.t(key);
  },

  @computed("checked", "checkedInternal")
  changed(checked, checkedInternal) {
    return !!checked !== !!checkedInternal;
  },

  actions: {
    cancelled() {
      this.set("checkedInternal", this.get("checked"));
    },

    finished() {
      this.set("checked", this.get("checkedInternal"));
      this.sendAction();
    }
  }
});
