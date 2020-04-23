import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["auth-token-dropdown"],

  selectKitOptions: {
    icon: "wrench",
    showFullTitle: false
  },

  content: computed(function() {
    return [
      {
        id: "notYou",
        icon: "user-times",
        name: I18n.t("user.auth_tokens.not_you"),
        description: ""
      },
      {
        id: "logOut",
        icon: "sign-out-alt",
        name: I18n.t("user.log_out"),
        description: ""
      }
    ];
  }),

  actions: {
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
});
