import { action, computed } from "@ember/object";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { inject as service } from "@ember/service";

export default DropdownSelectBoxComponent.extend({
  router: service(),

  classNames: ["email-dropdown"],

  selectKitOptions: {
    icon: "wrench",
    showFullTitle: false,
  },

  content: computed("email", function () {
    const content = [];

    if (this.email.primary) {
      content.push({
        id: "updateEmail",
        icon: "pencil-alt",
        name: I18n.t("user.email.update_email"),
        description: "",
      });
    }

    if (!this.email.primary && this.email.confirmed) {
      content.push({
        id: "setPrimaryEmail",
        icon: "star",
        name: I18n.t("user.email.set_primary"),
        description: "",
      });
    }

    if (!this.email.primary) {
      content.push({
        id: "destroyEmail",
        icon: "times",
        name: I18n.t("user.email.destroy"),
        description: "",
      });
    }

    return content;
  }),

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
  },
});
