import { iconHTML } from "discourse-common/lib/icon-library";
import DropdownButton from "discourse/components/dropdown-button";
import computed from "ember-addons/ember-computed-decorators";

export default DropdownButton.extend({
  buttonExtraClasses: "no-text",
  title: "",
  text: iconHTML("wrench"),
  classNames: ["auth-token-dropdown"],

  dropDownContent() {
    const items = [
      {
        id: "notYou",
        title: I18n.t("user.auth_tokens.not_you"),
        description: "",
        icon: "user-times"
      },
      {
        id: "logOut",
        title: I18n.t("user.log_out"),
        description: "",
        icon: "sign-out"
      }
    ];

    return items;
  },

  clicked(id) {
    switch (id) {
      case "notYou":
        this.sendAction("showToken", this.get("token"));
        break;
      case "logOut":
        this.sendAction("revokeAuthToken", this.get("token"));
        break;
    }
  }
});
