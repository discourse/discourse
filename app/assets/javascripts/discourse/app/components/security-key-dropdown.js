import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["security-key-dropdown"],

  selectKitOptions: {
    icon: "wrench",
    showFullTitle: false,
  },

  content: computed(function () {
    const content = [];

    content.push({
      id: "edit",
      icon: "pencil-alt",
      name: I18n.t("user.second_factor.edit"),
    });

    content.push({
      id: "disable",
      icon: "trash-alt",
      name: I18n.t("user.second_factor.disable"),
    });

    return content;
  }),

  actions: {
    onChange(id) {
      switch (id) {
        case "edit":
          this.editSecurityKey(this.securityKey);
          break;
        case "disable":
          this.disableSingleSecondFactor(this.securityKey);
          break;
      }
    },
  },
});
