import { and, reads } from "@ember/object/computed";
import SingleSelectHeaderComponent from "select-kit/components/select-kit/single-select-header";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/combo-box/combo-box-header";

export default SingleSelectHeaderComponent.extend({
  layout,
  classNames: ["combo-box-header"],
  clearable: reads("selectKit.options.clearable"),
  caretUpIcon: reads("selectKit.options.caretUpIcon"),
  caretDownIcon: reads("selectKit.options.caretDownIcon"),
  shouldDisplayClearableButton: and("clearable", "value"),

  caretIcon: computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon", {
    get() {
      return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
    },

    set(key, value) {
      return value;
    },
  }),
});
