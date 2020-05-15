import { getOwner } from "@ember/application";
import { computed } from "@ember/object";
import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["email-dropdown"],

  selectKitOptions: {
    icon: "wrench",
    showFullTitle: false
  },

  content: computed("email", function() {
    const content = [];

    if (this.email.primary) {
      content.push({
        id: "updateEmail",
        icon: "pencil-alt",
        name: I18n.t("user.email.update_email"),
        description: ""
      });
    }

    if (!this.email.primary && this.email.confirmed) {
      content.push({
        id: "setPrimaryEmail",
        icon: "star",
        name: I18n.t("user.email.set_primary"),
        description: ""
      });
    }

    if (!this.email.primary) {
      content.push({
        id: "destroyEmail",
        icon: "times",
        name: I18n.t("user.email.destroy"),
        description: ""
      });
    }

    return content;
  }),

  actions: {
    onChange(id) {
      switch (id) {
        case "updateEmail":
          getOwner(this)
            .lookup("router:main")
            .transitionTo("preferences.email");
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
});
