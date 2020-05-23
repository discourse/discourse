import SingleSelectComponent from "select-kit/components/single-select";

export default SingleSelectComponent.extend({
  pluginApiIdentifiers: ["dropdown-select-box"],
  classNames: ["dropdown-select-box"],

  selectKitOptions: {
    autoFilterable: false,
    filterable: false,
    showFullTitle: true,
    headerComponent: "dropdown-select-box/dropdown-select-box-header",
    caretUpIcon: "caret-up",
    caretDownIcon: "caret-down",
    showCaret: false
  },

  modifyComponentForRow() {
    return "dropdown-select-box/dropdown-select-box-row";
  }
});
