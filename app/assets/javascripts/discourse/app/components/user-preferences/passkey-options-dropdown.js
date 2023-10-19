import { action, computed } from "@ember/object";
import I18n from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["passkey-options-dropdown"],

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
  },
});
