import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  tagName: "th",
  classNames: ["sortable"],
  chevronIcon: null,
  toggleProperties() {
    if (this.order === this.field) {
      this.set("desc", this.desc ? null : true);
    } else {
      this.setProperties({ order: this.field, desc: null });
    }
  },
  toggleChevron() {
    if (this.order === this.field) {
      let chevron = iconHTML(this.desc ? "chevron-down" : "chevron-up");
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
