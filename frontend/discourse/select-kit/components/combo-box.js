import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import SingleSelectComponent from "discourse/select-kit/components/single-select";
import ComboBoxHeader from "./combo-box/combo-box-header";
import {
  FILTER_VISIBILITY_THRESHOLD,
  pluginApiIdentifiers,
  selectKitOptions,
} from "./select-kit";

@classNames("combobox", "combo-box")
@pluginApiIdentifiers(["combo-box"])
@selectKitOptions({
  caretUpIcon: "angle-up",
  caretDownIcon: "angle-down",
  autoFilterable: "autoFilterable",
  clearable: false,
  headerComponent: ComboBoxHeader,
  shouldDisplayIcon: false,
})
export default class ComboBox extends SingleSelectComponent {
  @computed("content.length")
  get autoFilterable() {
    return this.content?.length >= FILTER_VISIBILITY_THRESHOLD;
  }
}
