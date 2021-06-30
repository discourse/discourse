import ComboBoxComponent from "select-kit/components/combo-box";

export default ComboBoxComponent.extend({
  pluginApiIdentifiers: ["flair-chooser"],
  classNames: ["flair-chooser"],

  selectKitOptions: {
    selectedNameComponent: "selected-flair",
  },

  modifyComponentForRow() {
    return "flair-row";
  },
});
