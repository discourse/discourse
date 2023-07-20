import I18n from "I18n";
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";

export default class extends Component {
  @tracked filter = "";
  @tracked filterDropdownValue = "all";

  filterDropdownContent = [
    {
      id: "all",
      name: I18n.t("sidebar.edit_navigation_modal_form.filter_dropdown.all"),
    },
    {
      id: "selected",
      name: I18n.t(
        "sidebar.edit_navigation_modal_form.filter_dropdown.selected"
      ),
    },
    {
      id: "unselected",
      name: I18n.t(
        "sidebar.edit_navigation_modal_form.filter_dropdown.unselected"
      ),
    },
  ];

  @action
  onFilterInput(value) {
    this.args.onFilterInput(value);
  }

  @action
  onFilterDropdownChange(value) {
    this.filterDropdownValue = value;

    switch (value) {
      case "all":
        this.args.resetFilter();
        break;
      case "selected":
        this.args.filterSelected();
        break;
      case "unselected":
        this.args.filterUnselected();
        break;
    }
  }
}
