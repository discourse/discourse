import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DropdownSelectBoxComponent from "discourse/select-kit/components/dropdown-select-box";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";
import { i18n } from "discourse-i18n";

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
