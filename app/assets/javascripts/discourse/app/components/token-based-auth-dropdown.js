import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@classNames("token-based-auth-dropdown")
@selectKitOptions({
  icon: "wrench",
  showFullTitle: false,
})
export default class TokenBasedAuthDropdown extends DropdownSelectBoxComponent {
  @computed
  get content() {
    return [
      {
        id: "edit",
        icon: "pencil",
        name: i18n("user.second_factor.edit"),
      },
      {
        id: "disable",
        icon: "trash-can",
        name: i18n("user.second_factor.disable"),
      },
    ];
  }

  @action
  onChange(id) {
    switch (id) {
      case "edit":
        this.editSecondFactor(this.totp);
        break;
      case "disable":
        this.disableSingleSecondFactor(this.totp);
        break;
    }
  }
}
