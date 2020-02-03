import SelectKitComponent from "select-kit/components/select-kit";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";

export default SelectKitComponent.extend({
  pluginApiIdentifiers: ["single-select"],
  layoutName: "select-kit/templates/components/single-select",
  classNames: ["single-select"],
  singleSelect: true,

  selectKitOptions: {
    headerComponent: "select-kit/single-select-header"
  },

  selectedContent: computed("value", "content.[]", function() {
    if (!isEmpty(this.value)) {
      let content;

      if (this.selectKit.valueProperty) {
        content = (this.content || []).findBy(
          this.selectKit.valueProperty,
          this.value
        );
        return this.selectKit.modifySelection(
          content || this.defaultItem(this.value, this.value)
        );
      } else {
        return this.selectKit.modifySelection(
          (this.content || []).filter(c => c === this.value)
        );
      }
    } else {
      return this.selectKit.noneItem;
    }
  })
});
