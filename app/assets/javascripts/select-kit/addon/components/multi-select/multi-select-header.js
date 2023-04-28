import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import layout from "select-kit/templates/components/multi-select/multi-select-header";
import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";

export default SelectKitHeaderComponent.extend({
  tagName: "summary",
  classNames: ["multi-select-header"],
  attributeBindings: ["ariaLabel:aria-label"],
  layout,

  caretUpIcon: reads("selectKit.options.caretUpIcon"),
  caretDownIcon: reads("selectKit.options.caretDownIcon"),
  ariaLabel: reads("selectKit.options.headerAriaLabel"),
  caretIcon: computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon", {
    get() {
      if (this._caretIcon) {
        return this._caretIcon;
      } else {
        return this.selectKit.isExpanded
          ? this.caretUpIcon
          : this.caretDownIcon;
      }
    },

    set(key, value) {
      return (this.careIcon = value);
    },
  }),
});
