import { classNames } from "@ember-decorators/component";
import ComboBoxComponent from "select-kit/components/combo-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("user-nav-messages-dropdown")
@selectKitOptions({
  caretDownIcon: "caret-right",
  caretUpIcon: "caret-down",
})
@pluginApiIdentifiers("user-nav-messages-dropdown")
export default class MessagesDropdown extends ComboBoxComponent {}
