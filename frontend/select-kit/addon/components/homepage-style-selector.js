import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import HomepageStyleSelectorRow from "./homepage-style-selector/homepage-style-selector-row";
import { pluginApiIdentifiers } from "./select-kit";

@classNames("homepage-style-selector")
@pluginApiIdentifiers(["homepage-style-selector"])
export default class HomepageStyleSelector extends ComboBoxComponent {
  modifyComponentForRow() {
    return HomepageStyleSelectorRow;
  }
}
