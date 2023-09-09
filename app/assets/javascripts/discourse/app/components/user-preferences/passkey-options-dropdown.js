import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import I18n from "I18n";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["token-based-auth-dropdown"],

  selectKitOptions: {
    icon: "wrench",
    showFullTitle: false,
  },

  content: computed(function () {
    return [
      {
        id: "edit",
        icon: "pencil-alt",
        name: I18n.t("user.second_factor.edit"),
      },
      {
        id: "delete",
        icon: "trash-alt",
        name: I18n.t("user.second_factor.delete"),
      },
    ];
  }),

  actions: {
    onChange(id) {
      switch (id) {
        case "edit":
          this.renamePasskey(this.passkeyId);
          break;
        case "delete":
          this.deletePasskey(this.passkeyId);
          break;
      }
    },
  },
});
