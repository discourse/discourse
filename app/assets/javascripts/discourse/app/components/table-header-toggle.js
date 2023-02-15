import Component from "@ember/component";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";
import { schedule } from "@ember/runloop";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "I18n";

export default Component.extend({
  tagName: "div",
  classNames: ["directory-table__row", "sortable"],
  attributeBindings: ["title", "colspan", "ariaSort:aria-sort", "role"],
  role: "columnheader",
  labelKey: null,
  chevronIcon: null,
  columnIcon: null,
  translated: false,
  automatic: false,
  onActiveRender: null,
  pressedState: null,
  ariaLabel: null,

  @discourseComputed("order", "field", "asc")
  ariaSort() {
    if (this.order === this.field) {
      return this.asc ? "ascending" : "descending";
    } else {
      return "none";
    }
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
      this.set("chevronIcon", htmlSafe(`${chevron}`));
    } else {
      this.set("chevronIcon", null);
    }
  },
  click() {
    this.toggleProperties();
  },
  keyPress(e) {
    if (e.which === 13) {
      this.toggleProperties();
    }
  },
  didReceiveAttrs() {
    this._super(...arguments);
    if (!this.automatic && !this.translated) {
      this.set("labelKey", this.field);
    }
    this.set("id", `table-header-toggle-${this.field.replace(/\s/g, "")}`);
    this.toggleChevron();
    this._updateA11yAttributes();
  },
  didRender() {
    if (this.onActiveRender && this.chevronIcon) {
      this.onActiveRender(this.element);
    }
  },
  _updateA11yAttributes() {
    let criteria = "";
    const pressed = this.order === this.field;

    if (this.icon === "heart") {
      criteria += `${I18n.t("likes_lowercase", { count: 2 })} `;
    }

    if (this.translated) {
      criteria += this.field;
    } else {
      const labelKey = this.labelKey || `directory.${this.field}`;

      criteria += I18n.t(labelKey + "_long", {
        defaultValue: I18n.t(labelKey),
      });
    }

    this.set("ariaLabel", I18n.t("directory.sort.label", { criteria }));

    if (pressed) {
      if (this.asc) {
        this.set("pressedState", "mixed");
      } else {
        this.set("pressedState", "true");
      }

      this._focusHeader();
    } else {
      this.set("pressedState", "false");
    }
  },
  _focusHeader() {
    schedule("afterRender", () => {
      document.getElementById(this.id)?.focus();
    });
  },
});
