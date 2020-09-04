import SelectKitComponent from "select-kit/components/select-kit";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import layout from "select-kit/templates/components/single-select";

export default SelectKitComponent.extend({
  pluginApiIdentifiers: ["single-select"],
  layout,
  classNames: ["single-select"],
  singleSelect: true,

  selectKitOptions: {
    headerComponent: "select-kit/single-select-header",
  },

  selectedContent: computed(
    "value",
    "content.[]",
    "selectKit.noneItem",
    function () {
      if (!isEmpty(this.value)) {
        let content;

        const value =
          this.selectKit.options.castInteger && this._isNumeric(this.value)
            ? Number(this.value)
            : this.value;

        if (this.selectKit.valueProperty) {
          content = (this.content || []).findBy(
            this.selectKit.valueProperty,
            value
          );

          return this.selectKit.modifySelection(
            content || this.defaultItem(value, value)
          );
        } else {
          return this.selectKit.modifySelection(
            (this.content || []).filter((c) => c === value)
          );
        }
      } else {
        return this.selectKit.noneItem;
      }
    }
  ),
});
