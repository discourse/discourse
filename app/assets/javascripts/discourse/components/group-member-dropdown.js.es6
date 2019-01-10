import computed from "ember-addons/ember-computed-decorators";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  pluginApiIdentifiers: ["group-member-dropdown"],
  classNames: "group-member-dropdown",
  showFullTitle: false,
  allowInitialValueMutation: false,
  allowAutoSelectFirst: false,
  headerIcon: ["wrench"],

  autoHighlight() {},

  @computed("member.owner")
  content(isOwner) {
    const items = [
      {
        id: "removeMember",
        name: I18n.t("groups.members.remove_member"),
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
          name: I18n.t("groups.members.remove_owner"),
          description: I18n.t("groups.members.remove_owner_description", {
            username: this.get("member.username")
          }),
          icon: "shield"
        });
      } else {
        items.push({
          id: "makeOwner",
          name: I18n.t("groups.members.make_owner"),
          description: I18n.t("groups.members.make_owner_description", {
            username: this.get("member.username")
          }),
          icon: "shield"
        });
      }
    }

    return items;
  },

  mutateValue(id) {
    switch (id) {
      case "removeMember":
        this.removeMember(this.get("member"));
        break;
      case "makeOwner":
        this.makeOwner(this.get("member.username"));
        break;
      case "removeOwner":
        this.removeOwner(this.get("member"));
        break;
    }
  }
});
