import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";

export default SelectKitHeaderComponent.extend({
  tagName: "summary",
  classNames: ["multi-select-header"],
  attributeBindings: ["ariaLabel:aria-label"],
  caretUpIcon: reads("selectKit.options.caretUpIcon"),
  caretDownIcon: reads("selectKit.options.caretDownIcon"),
  ariaLabel: reads("selectKit.options.headerAriaLabel"),

  caretIcon: computed(
    "selectKit.isExpanded",
    "caretUpIcon",
    "caretDownIcon",
    function () {
      return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
    }
  ),
});
