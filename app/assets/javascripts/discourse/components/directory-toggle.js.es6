import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";

export default Component.extend({
  tagName: "th",
  classNames: ["sortable"],
  attributeBindings: ["title"],
  labelKey: null,
  chevronIcon: null,
  columnIcon: null,

  @discourseComputed("field", "labelKey")
  title(field, labelKey) {
    if (!labelKey) {
      labelKey = `directory.${this.field}`;
    }

    return I18n.t(labelKey + "_long", { defaultValue: I18n.t(labelKey) });
  },

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
    this.toggleChevron();
  },
  init() {
    this._super(...arguments);
    if (this.icon) {
      let columnIcon = iconHTML(this.icon);
      this.set("columnIcon", `${columnIcon}`.htmlSafe());
    }
  }
});
