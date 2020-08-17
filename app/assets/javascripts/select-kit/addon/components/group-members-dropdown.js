import I18n from "I18n";
import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";
import { action, computed } from "@ember/object";

export default DropdownSelectBoxComponent.extend({
  classNames: ["group-members-dropdown"],

  selectKitOptions: {
    icon: "bars",
    showFullTitle: false
  },

  content: computed(function() {
    const items = [
      {
        id: "showAddMembersModal",
        name: I18n.t("groups.add_members.title", {
          group_name: this.groupName
        }),
        icon: "user-plus"
      }
    ];
    return items;
  }),

  @action
  onChange(id) {
    this.attrs && this.attrs[id] && this.attrs[id]();
  }
});
