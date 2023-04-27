import SingleSelectHeaderComponent from "select-kit/components/select-kit/single-select-header";
import { computed } from "@ember/object";
import layout from "select-kit/templates/components/dropdown-select-box/dropdown-select-box-header";
import { readOnly } from "@ember/object/computed";

export default SingleSelectHeaderComponent.extend({
  layout,
  classNames: ["dropdown-select-box-header"],
  classNameBindings: ["btnClassName", "btnStyleClass"],
  showFullTitle: readOnly("selectKit.options.showFullTitle"),
  customStyle: readOnly("selectKit.options.customStyle"),

  btnClassName: computed("showFullTitle", function () {
    return `btn ${this.showFullTitle ? "btn-icon-text" : "no-text btn-icon"}`;
  }),

  btnStyleClass: computed("customStyle", function () {
    return `${this.customStyle ? "" : "btn-default"}`;
  }),

  caretUpIcon: readOnly("selectKit.options.caretUpIcon"),

  caretDownIcon: readOnly("selectKit.options.caretDownIcon"),

  caretIcon: computed("selectKit.isExpanded", "caretUpIcon", "caretDownIcon", {
    get() {
      return this.selectKit.isExpanded ? this.caretUpIcon : this.caretDownIcon;
    },

    set(key, value) {
      return value;
    },
  }),
});
