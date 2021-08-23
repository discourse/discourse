import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import layout from "select-kit/templates/components/multi-select/multi-select-header";
import { computed } from "@ember/object";
import { reads } from "@ember/object/computed";

export default SelectKitHeaderComponent.extend({
  tagName: "summary",
  classNames: ["multi-select-header"],
  layout,

  caretUpIcon: reads("selectKit.options.caretUpIcon"),
  caretDownIcon: reads("selectKit.options.caretDownIcon"),
  caretIcon: computed(
    "selectKit.isExpanded",
    "caretUpIcon",
    "caretDownIcon",
    function () {
      return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
    }
  ),
});
