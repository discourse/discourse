import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: ["auth-token-dropdown"],
  headerIcon: "wrench",
  allowInitialValueMutation: false,
  showFullTitle: false,

  computeContent() {
    const content = [
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

    return content;
  },

  actions: {
    onSelect(id) {
      switch (id) {
        case "notYou":
          this.showToken(this.get("token"));
          break;
        case "logOut":
          this.revokeAuthToken(this.get("token"));
          break;
      }
    }
  }
});
