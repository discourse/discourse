import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { selectKitOptions } from "select-kit/components/select-kit";

@classNames("security-key-dropdown")
@selectKitOptions({
  icon: "wrench",
  showFullTitle: false,
})
export default class SecurityKeyDropdown extends DropdownSelectBoxComponent {
  @computed
  get content() {
    const content = [];

    content.push({
      id: "edit",
      icon: "pencil",
      name: i18n("user.second_factor.edit"),
    });

    content.push({
      id: "disable",
      icon: "trash-can",
      name: i18n("user.second_factor.disable"),
    });

    return content;
  }

  @action
  onChange(id) {
    switch (id) {
      case "edit":
        this.editSecurityKey(this.securityKey);
        break;
      case "disable":
        this.disableSingleSecondFactor(this.securityKey);
        break;
    }
  }
}
