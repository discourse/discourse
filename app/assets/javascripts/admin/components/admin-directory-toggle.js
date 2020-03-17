import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  tagName: "th",
  classNames: ["sortable"],
  chevronIcon: null,
  toggleProperties() {
    if (this.order === this.field) {
      this.set("ascending", this.ascending ? null : true);
    } else {
      this.setProperties({ order: this.field, ascending: null });
    }
  },
  toggleChevron() {
    if (this.order === this.field) {
      let chevron = iconHTML(this.ascending ? "chevron-up" : "chevron-down");
      this.set("chevronIcon", `${chevron}`.htmlSafe());
    } else {
      this.set("chevronIcon", null);
    }
  },
  click() {
    this.toggleProperties();
  },
  didReceiveAttrs() {
    this._super(...arguments);
    this.toggleChevron();
  }
});
