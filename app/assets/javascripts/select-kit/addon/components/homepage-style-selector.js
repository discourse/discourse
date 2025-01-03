import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import { pluginApiIdentifiers } from "./select-kit";

@classNames("homepage-style-selector")
@pluginApiIdentifiers(["homepage-style-selector"])
export default class HomepageStyleSelector extends ComboBoxComponent {
  modifyComponentForRow() {
    return "homepage-style-selector/homepage-style-selector-row";
  }
}
