import DropdownSelectBoxComponent from "select-kit/components/dropdown-select-box";

export default DropdownSelectBoxComponent.extend({
  classNames: "groups-admin-dropdown pull-right",
  headerIcon: ["bars", "caret-down"],
  showFullTitle: false,

  computeContent() {
    const items = [
      {
        id: "new",
        name: I18n.t("groups.new.title"),
        description: I18n.t("groups.new.description"),
        icon: "plus"
      }
    ];

    return items;
  },

  mutateValue(value) {
    switch (value) {
      case 'new': {
        this.sendAction("new");
        break;
      }
    }
  },
});
