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
import CreateColorRow from "./create-color-row";
import SelectedChoice from "./selected-choice";
import SelectedChoiceColor from "./selected-choice-color";

@classNames("list-setting")
@selectKitOptions({
  filterable: true,
})
@pluginApiIdentifiers("list-setting")
export default class ListSetting extends MultiSelectComponent {
  choices = null;
  nameProperty = null;
  valueProperty = null;

  @readOnly("choices") content;

  modifyComponentForRow(collection) {
    if (collection === MAIN_COLLECTION && this.settingName?.includes("color")) {
      return CreateColorRow;
    }
  }

  @computed("settingName")
  get selectedChoiceComponent() {
    if (this.settingName?.includes("color")) {
      return SelectedChoiceColor;
    } else {
      return SelectedChoice;
    }
  }

  deselect(value) {
    this.onChangeChoices &&
      this.onChangeChoices([...new Set([value, ...makeArray(this.choices)])]);

    super.deselect(...arguments);
  }
}
