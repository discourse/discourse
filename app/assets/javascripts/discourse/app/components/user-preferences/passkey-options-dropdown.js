import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@classNames("passkey-options-dropdown")
@selectKitOptions({
  icon: "wrench",
  showFullTitle: false,
})
export default class PasskeyOptionsDropdown extends DropdownSelectBoxComponent {
  @computed
  get content() {
    return [
      {
        id: "edit",
        icon: "pencil",
        name: I18n.t("user.second_factor.edit"),
      },
      {
        id: "delete",
        icon: "trash-can",
        name: I18n.t("user.second_factor.delete"),
      },
    ];
  }

  @action
  onChange(id) {
    switch (id) {
      case "edit":
        this.renamePasskey();
        break;
      case "delete":
        this.deletePasskey();
        break;
    }
  }
}
