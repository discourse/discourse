import SelectKitHeaderComponent from "select-kit/components/select-kit/select-kit-header";
import { computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";

export default SelectKitHeaderComponent.extend({
  classNames: ["multi-select-header"],
  layoutName:
    "select-kit/templates/components/multi-select/multi-select-header",

  selectedNames: computed("selectedContent", function() {
    return makeArray(this.selectedContent).map(c => this.getName(c));
  }),

  selectedValue: computed("selectedContent", function() {
    return makeArray(this.selectedContent)
      .map(c => {
        if (this.getName(c) !== this.getName(this.selectKit.noneItem)) {
          return this.getValue(c);
        }

        return null;
      })
      .filter(Boolean);
  })
});
