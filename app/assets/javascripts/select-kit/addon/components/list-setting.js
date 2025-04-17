import { computed } from "@ember/object";
import { readOnly } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import MultiSelectComponent from "select-kit/components/multi-select";
import {
  MAIN_COLLECTION,
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("list-setting")
@selectKitOptions({
  filterable: true,
  selectedChoiceComponent: "selectedChoiceComponent",
})
@pluginApiIdentifiers("list-setting")
export default class ListSetting extends MultiSelectComponent {
  choices = null;
  nameProperty = null;
  valueProperty = null;

  @readOnly("choices") content;

  modifyComponentForRow(collection) {
    if (collection === MAIN_COLLECTION && this.settingName?.includes("color")) {
      return "create-color-row";
    }
  }

  @computed("settingName")
  get selectedChoiceComponent() {
    if (this.settingName?.includes("color")) {
      return "selected-choice-color";
    } else {
      return "selected-choice";
    }
  }

  deselect(value) {
    this.onChangeChoices &&
      this.onChangeChoices([...new Set([value, ...makeArray(this.choices)])]);

    super.deselect(...arguments);
  }
}
