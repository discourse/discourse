import { readOnly } from "@ember/object/computed";
import { computed } from "@ember/object";
import DropdownSelectBoxRowComponent from "select-kit/components/dropdown-select-box/dropdown-select-box-row";
import { escapeExpression } from "discourse/lib/utilities";

export default DropdownSelectBoxRowComponent.extend({
  classNames: ["notifications-button-row"],
  i18nPrefix: readOnly("selectKit.options.i18nPrefix"),
  i18nPostfix: readOnly("selectKit.options.i18nPostfix"),

  label: computed("_start", function() {
    return escapeExpression(I18n.t(`${this._start}.title`));
  }),

  title: readOnly("label"),

  icons: computed("title", "item.icon", function() {
    return [escapeExpression(this.item.icon)];
  }),

  description: computed("_start", function() {
    if (this.site && this.site.mobileView) {
      return null;
    }

    return escapeExpression(I18n.t(`${this._start}.description`));
  }),

  _start: computed("i18nPrefix", "i18nPostfix", "rowName", function() {
    return `${this.i18nPrefix}.${this.rowName}${this.i18nPostfix}`;
  })
});
