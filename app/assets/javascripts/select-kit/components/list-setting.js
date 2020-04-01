import MultiSelectComponent from "select-kit/components/multi-select";
import { MAIN_COLLECTION } from "select-kit/components/select-kit";
import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { makeArray } from "discourse-common/lib/helpers";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["list-setting"],
  classNames: ["list-setting"],
  choices: null,
  nameProperty: null,
  valueProperty: null,
  content: readOnly("choices"),

  selectKitOptions: {
    filterable: true,
    selectedNameComponent: "selectedNameComponent"
  },

  modifyComponentForRow(collection) {
    if (
      collection === MAIN_COLLECTION &&
      this.settingName &&
      this.settingName.indexOf("color") > -1
    ) {
      return "create-color-row";
    }
  },

  selectedNameComponent: computed("settingName", function() {
    if (this.settingName && this.settingName.indexOf("color") > -1) {
      return "selected-color";
    } else {
      return "selected-name";
    }
  }),

  deselect(value) {
    this.onChangeChoices &&
      this.onChangeChoices([...new Set([value, ...makeArray(this.choices)])]);

    this._super(...arguments);
  }
});
