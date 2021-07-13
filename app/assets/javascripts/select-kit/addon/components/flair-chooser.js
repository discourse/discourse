import { computed } from "@ember/object";
import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["flair-chooser"],
  classNames: ["flair-chooser"],

  selectKitOptions: {
    selectedNameComponent: "selected-flair",
  },

  modifyComponentForRow() {
    return "flair-row";
  },

  selectedContent: computed(
    "value",
    "content.[]",
    "selectKit.noneItem",
    function () {
      const content = (this.content || []).findBy(
        this.selectKit.valueProperty,
        this.value
      );

      if (content) {
        return this.selectKit.modifySelection(content);
      } else {
        return this.selectKit.noneItem;
      }
    }
  ),
});
