import { action, computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import DropdownSelectBoxComponent from "discourse/select-kit/components/dropdown-select-box";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";
import { i18n } from "discourse-i18n";

@classNames("auth-token-dropdown")
@selectKitOptions({
  icon: "wrench",
  showFullTitle: false,
})
export default class AuthTokenDropdown extends DropdownSelectBoxComponent {
  @computed
  get content() {
    return [
      {
        id: "notYou",
        icon: "user-xmark",
        name: i18n("user.auth_tokens.not_you"),
        description: "",
      },
      {
        id: "logOut",
        icon: "right-from-bracket",
        name: i18n("user.log_out"),
        description: "",
      },
    ];
  }

  @action
  onChange(id) {
    switch (id) {
      case "notYou":
        this.showToken(this.token);
        break;
      case "logOut":
        this.revokeAuthToken(this.token);
        break;
    }
  }
}
