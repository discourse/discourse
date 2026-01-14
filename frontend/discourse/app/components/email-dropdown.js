import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";
import DropdownSelectBoxComponent from "discourse/select-kit/components/dropdown-select-box";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";
import { i18n } from "discourse-i18n";

@classNames("email-dropdown")
@selectKitOptions({
  icon: "wrench",
  showFullTitle: false,
})
export default class EmailDropdown extends DropdownSelectBoxComponent {
  @service router;

  @computed("email")
  get content() {
    const content = [];

    if (this.email.primary) {
      content.push({
        id: "updateEmail",
        icon: "pencil",
        name: i18n("user.email.update_email"),
        description: "",
      });
    }

    if (!this.email.primary && this.email.confirmed) {
      content.push({
        id: "setPrimaryEmail",
        icon: "star",
        name: i18n("user.email.set_primary"),
        description: "",
      });
    }

    if (!this.email.primary) {
      content.push({
        id: "destroyEmail",
        icon: "xmark",
        name: i18n("user.email.destroy"),
        description: "",
      });
    }

    return content;
  }

  @action
  onChange(id) {
    switch (id) {
      case "updateEmail":
        this.router.transitionTo("preferences.email");
        break;
      case "setPrimaryEmail":
        this.setPrimaryEmail(this.email.email);
        break;
      case "destroyEmail":
        this.destroyEmail(this.email.email);
        break;
    }
  }
}
