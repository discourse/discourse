import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  tagName: "th",
  classNames: ["sortable"],
  attributeBindings: ["title"],
  labelKey: null,
  chevronIcon: null,
  columnIcon: null,
  translated: false,
  automatic: false,
  onActiveRender: null,

  toggleProperties() {
    if (this.order === this.field) {
      this.set("asc", this.asc ? null : true);
    } else {
      this.setProperties({ order: this.field, asc: null });
    }
  },
  toggleChevron() {
    if (this.order === this.field) {
      let chevron = iconHTML(this.asc ? "chevron-up" : "chevron-down");
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
    if (!this.automatic && !this.translated) {
      this.set("labelKey", this.field);
    }
    this.set("id", `table-header-toggle-${this.field.replace(/\s/g, "")}`);
    this.toggleChevron();
  },
  didRender() {
    if (this.onActiveRender && this.chevronIcon) {
      this.onActiveRender(this.element);
    }
  },
});
