import { iconHTML } from "discourse-common/lib/icon-library";
import DropdownButton from "discourse/components/dropdown-button";
import computed from "ember-addons/ember-computed-decorators";

export default DropdownButton.extend({
  buttonExtraClasses: "no-text",
  title: "",
  text: iconHTML("wrench"),
  classNames: ["group-member-dropdown"],

  @computed("member.owner")
  dropDownContent(isOwner) {
    const items = [
      {
        id: "removeMember",
        title: I18n.t("groups.members.remove_member"),
        description: I18n.t("groups.members.remove_member_description", {
          username: this.get("member.username")
        }),
        icon: "user-times"
      }
    ];

    if (this.currentUser && this.currentUser.admin) {
      if (isOwner) {
        items.push({
          id: "removeOwner",
          title: I18n.t("groups.members.remove_owner"),
          description: I18n.t("groups.members.remove_owner_description", {
            username: this.get("member.username")
          }),
          icon: "shield"
        });
      } else {
        items.push({
          id: "makeOwner",
          title: I18n.t("groups.members.make_owner"),
          description: I18n.t("groups.members.make_owner_description", {
            username: this.get("member.username")
          }),
          icon: "shield"
        });
      }
    }

    return items;
  },

  clicked(id) {
    switch (id) {
      case "removeMember":
        this.sendAction("removeMember", this.get("member"));
        break;
      case "makeOwner":
        this.sendAction("makeOwner", this.get("member.username"));
        break;
      case "removeOwner":
        this.sendAction("removeOwner", this.get("member"));
        break;
    }
  }
});
