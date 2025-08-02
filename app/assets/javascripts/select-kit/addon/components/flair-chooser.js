import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";
import FlairRow from "./flair-row";
import SelectedFlair from "./selected-flair";

@classNames("flair-chooser")
@selectKitOptions({
  selectedNameComponent: SelectedFlair,
})
@pluginApiIdentifiers(["flair-chooser"])
export default class FlairChooser extends ComboBoxComponent {
  modifyComponentForRow() {
    return FlairRow;
  }

  @computed("value", "content.[]", "selectKit.noneItem")
  get selectedContent() {
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
}
