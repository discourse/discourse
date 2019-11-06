import Component from "@ember/component";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNames: ["inline-edit"],

  checked: null,
  checkedInternal: null,

  init() {
    this._super(...arguments);

    this.set("checkedInternal", this.checked);
  },

  @observes("checked")
  checkedChanged() {
    this.set("checkedInternal", this.checked);
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
      this.set("checkedInternal", this.checked);
    },

    finished() {
      this.set("checked", this.checkedInternal);
      this.action();
    }
  }
});
