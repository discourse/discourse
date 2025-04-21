import { computed } from "@ember/object";
import { classNames } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import {
  pluginApiIdentifiers,
  selectKitOptions,
} from "select-kit/components/select-kit";

@classNames("group-member-dropdown")
@selectKitOptions({
  icon: "wrench",
  showFullTitle: false,
})
@pluginApiIdentifiers("group-member-dropdown")
export default class GroupMemberDropdown extends DropdownSelectBoxComponent {
  @computed("member.owner", "member.primary")
  get content() {
    const items = [
      {
        id: "removeMember",
        name: i18n("groups.members.remove_member"),
        description: i18n("groups.members.remove_member_description", {
          username: this.get("member.username"),
        }),
        icon: "user-xmark",
      },
    ];

    if (this.canAdminGroup) {
      if (this.member.owner) {
        items.push({
          id: "removeOwner",
          name: i18n("groups.members.remove_owner"),
          description: i18n("groups.members.remove_owner_description", {
            username: this.get("member.username"),
          }),
          icon: "shield-halved",
        });
      } else {
        items.push({
          id: "makeOwner",
          name: i18n("groups.members.make_owner"),
          description: i18n("groups.members.make_owner_description", {
            username: this.get("member.username"),
          }),
          icon: "shield-halved",
        });
      }
    } else if (this.canEditGroup && !this.member.owner) {
      items.push({
        id: "makeOwner",
        name: i18n("groups.members.make_owner"),
        description: i18n("groups.members.make_owner_description", {
          username: this.get("member.username"),
        }),
        icon: "shield-halved",
      });
    }

    if (this.currentUser.staff) {
      if (this.member.primary) {
        items.push({
          id: "removePrimary",
          name: i18n("groups.members.remove_primary"),
          description: i18n("groups.members.remove_primary_description", {
            username: this.get("member.username"),
          }),
          icon: "id-card",
        });
      } else {
        items.push({
          id: "makePrimary",
          name: i18n("groups.members.make_primary"),
          description: i18n("groups.members.make_primary_description", {
            username: this.get("member.username"),
          }),
          icon: "id-card",
        });
      }
    }

    return items;
  }
}
