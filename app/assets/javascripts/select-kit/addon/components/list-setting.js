import { MAIN_COLLECTION } from "select-kit/components/select-kit";
import MultiSelectComponent from "select-kit/components/multi-select";
import { computed } from "@ember/object";
import { makeArray } from "discourse-common/lib/helpers";
import { readOnly } from "@ember/object/computed";

export default MultiSelectComponent.extend({
  pluginApiIdentifiers: ["list-setting"],
  classNames: ["list-setting"],
  choices: null,
  nameProperty: null,
  valueProperty: null,
  content: readOnly("choices"),

  selectKitOptions: {
    filterable: true,
    selectedChoiceComponent: "selectedChoiceComponent",
  },

  modifyComponentForRow(collection) {
    if (collection === MAIN_COLLECTION && this.settingName?.includes("color")) {
      return "create-color-row";
    }
  },

  selectedChoiceComponent: computed("settingName", function () {
    if (this.settingName?.includes("color")) {
      return "selected-choice-color";
    } else {
      return "selected-choice";
    }
  }),

  deselect(value) {
    this.onChangeChoices &&
      this.onChangeChoices([...new Set([value, ...makeArray(this.choices)])]);

    this._super(...arguments);
  },
});
