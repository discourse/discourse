import MultiComboBoxComponent from "select-box-kit/components/multi-combo-box";

export default MultiComboBoxComponent.extend({
  classNames: "admin-group-selector",

  actions: {
    onSelect(value) {
      this.defaultOnSelect();
      this.triggerAction({ action: "groupAdded", actionContext: value });
    },

    onDeselect(value) {
      this.defaultOnDeselect();

      this.triggerAction({
        action: "groupRemoved",
        actionContext: value
      });
    }
  }
});
