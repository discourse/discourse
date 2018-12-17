import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["inline-edit"],

  checked: null,
  checkedInternal: null,

  init() {
    this._super(...arguments);

    this.set("checkedInternal", this.get("checked"));
  },

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
      this.action();
    }
  }
});
