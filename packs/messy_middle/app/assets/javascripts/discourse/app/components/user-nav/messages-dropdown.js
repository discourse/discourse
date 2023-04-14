import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["user-nav-messages-dropdown"],
  classNames: ["user-nav-messages-dropdown"],

  selectKitOptions: {
    caretDownIcon: "caret-right",
    caretUpIcon: "caret-down",
  },
});
