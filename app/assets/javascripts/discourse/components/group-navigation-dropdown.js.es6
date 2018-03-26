import DropdownSelectBox from "select-kit/components/dropdown-select-box";

export default DropdownSelectBox.extend({
  classNames: ["group-navigation-dropdown", "pull-right"],
  nameProperty: "label",
  headerIcon: ["bars"],
  showFullTitle: false,

  computeContent() {
    const content = [];

    content.push({
      id: "manageMembership",
      icon: "user-plus",
      label: I18n.t("groups.add_members.title"),
      description:  I18n.t("groups.add_members.description"),
    });

    return content;
  },

  mutateValue(value) {
    this.get(value)(this.get('model'));
  }
});
